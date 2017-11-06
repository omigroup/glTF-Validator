/*
 * # Copyright (c) 2016-2017 The Khronos Group Inc.
 * # Copyright (c) 2016 Alexey Knyazev
 * #
 * # Licensed under the Apache License, Version 2.0 (the "License");
 * # you may not use this file except in compliance with the License.
 * # You may obtain a copy of the License at
 * #
 * #     http://www.apache.org/licenses/LICENSE-2.0
 * #
 * # Unless required by applicable law or agreed to in writing, software
 * # distributed under the License is distributed on an "AS IS" BASIS,
 * # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * # See the License for the specific language governing permissions and
 * # limitations under the License.
 */

library gltf.data_access.resources_loader;

import 'dart:async';
import 'package:gltf/gltf.dart';
import 'package:gltf/src/base/gltf_property.dart';
import 'package:gltf/src/data_access/image_decoder.dart';
import 'package:gltf/src/data_access/validate_accessors.dart';
import 'package:meta/meta.dart';

typedef Stream<List<int>> SequentialFetchFunction(Uri uri);
typedef FutureOr<List<int>> BytesFetchFunction(Uri uri);

enum _Storage { Base64, BufferView, GLB, External }

class ResourceInfo {
  final String pointer;
  String mimeType;
  _Storage storage;
  int byteLength;
  String uri;
  ImageInfo image;

  ResourceInfo(this.pointer);

  Map<String, Object> toMap() {
    assert(pointer != null && storage != null);
    const storageString = const <String>[
      'base64',
      'bufferView',
      'glb',
      'external'
    ];

    final map = <String, Object>{
      'pointer': pointer,
      'mimeType': mimeType,
      'storage': storageString[storage.index]
    };

    addToMapIfNotNull(map, 'uri', uri);
    addToMapIfNotNull(map, 'byteLength', byteLength);
    addToMapIfNotNull(map, 'image', image?.toMap());

    return map;
  }
}

class ResourcesLoader {
  final Gltf gltf;
  final Context context;

  final BytesFetchFunction externalBytesFetch;
  final SequentialFetchFunction externalStreamFetch;

  ResourcesLoader(this.context, this.gltf,
      {@required this.externalBytesFetch, @required this.externalStreamFetch});

  Future<Null> load() async {
    try {
      await _loadBuffers();
      await _loadImages();
      if (context.validate) {
        validateAccessorsData(gltf, context);
      }
    } on IssuesLimitExceededException catch (_) {
      return null;
    }
  }

  Future<Null> _loadBuffers() async {
    context.path
      ..clear()
      ..add(BUFFERS);

    for (var i = 0; i < gltf.buffers.length; i++) {
      final buffer = gltf.buffers[i];
      context.path.add(i.toString());

      final info = new ResourceInfo(context.getPointerString())
        ..mimeType = APPLICATION_GLTF_BUFFER;

      FutureOr<List<int>> _fetchBuffer(Buffer buffer) {
        if (buffer.extensions.isEmpty) {
          if (buffer.uri != null) {
            // External fetch
            info
              ..storage = _Storage.External
              ..uri = buffer.uri.toString();
            return externalBytesFetch(buffer.uri);
          } else if (buffer.data != null) {
            // Data URI
            info.storage = _Storage.Base64;
            return buffer.data;
          } else {
            // GLB Buffer
            info.storage = _Storage.GLB;
            return externalBytesFetch(null);
          }
        } else {
          throw new UnimplementedError();
        }
      }

      List<int> data;
      try {
        data = await _fetchBuffer(buffer);
      } on Exception catch (e) {
        // likely IO error
        context.addIssue(IoError.fileNotFound, args: [e]);
      }

      if (data != null) {
        info.byteLength = data.length;
        if (data.length < buffer.byteLength) {
          context.addIssue(DataError.bufferExternalBytelengthMismatch,
              args: [data.length, buffer.byteLength]);
        } else {
          if (buffer.uri == null) {
            final paddedLength = padLength(buffer.byteLength);
            if (data.length > paddedLength) {
              context.addIssue(DataError.bufferGlbChunkTooBig,
                  args: [data.length - paddedLength]);
            }
          }
          // ignore: invalid_assignment
          buffer.data ??= data;
        }
      }
      context.addResource(info.toMap());
      context.path.removeLast();
    }
  }

  Future<Null> _loadImages() async {
    context.path
      ..clear()
      ..add(IMAGES);

    for (var i = 0; i < gltf.images.length; i++) {
      final image = gltf.images[i];
      context.path.add(i.toString());

      final resourceInfo = new ResourceInfo(context.getPointerString());

      Stream<List<int>> _fetchImageData(Image image) {
        if (image.extensions.isEmpty) {
          if (image.uri != null) {
            // External fetch
            resourceInfo
              ..storage = _Storage.External
              ..uri = image.uri.toString();
            return externalStreamFetch(image.uri);
          } else if (image.data != null && image.mimeType != null) {
            // Data URI, preloaded on phase 2 of GltfLoader
            resourceInfo.storage = _Storage.Base64;
            return new Stream.fromIterable([image.data]);
          } else if (image.bufferView != null) {
            // BufferView
            resourceInfo.storage = _Storage.BufferView;
            image.tryLoadFromBufferView();
            if (image.data != null) {
              return new Stream.fromIterable([image.data]);
            }
          }
          return null;
        } else {
          throw new UnimplementedError();
        }
      }

      final imageDataStream = _fetchImageData(image);

      ImageInfo imageInfo;
      if (imageDataStream != null) {
        try {
          imageInfo = await ImageInfo.parseStreamAsync(imageDataStream);
        } on UnsupportedImageFormatException catch (_) {
          context.addIssue(DataError.imageUnrecognizedFormat);
        } on UnexpectedEndOfStreamException catch (_) {
          context.addIssue(DataError.imageUnexpectedEos);
        } on InvalidDataFormatException catch (e) {
          context.addIssue(DataError.imageDataInvalid, args: [e]);
        } on Exception catch (e) {
          // likely IO error
          context.addIssue(IoError.fileNotFound, args: [e]);
        }
        if (imageInfo != null) {
          resourceInfo.mimeType = imageInfo.mimeType;

          if (context.validate) {
            if (image.mimeType != null &&
                (image.mimeType != imageInfo.mimeType)) {
              context.addIssue(DataError.imageMimeTypeInvalid,
                  args: [imageInfo.mimeType, image.mimeType]);
            }

            if (!isPot(imageInfo.width) || !isPot(imageInfo.height)) {
              context.addIssue(DataError.imageNonPowerOfTwoDimensions,
                  args: [imageInfo.width, imageInfo.height]);
            }
          }

          // Store image metadata in glTF image object
          image.info = imageInfo;

          // Store image metadata in ResourceInfo
          resourceInfo.image = imageInfo;
        }
      }
      context.addResource(resourceInfo.toMap());
      context.path.removeLast();
    }
  }
}
