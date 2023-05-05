// Copyright 2023 The Khronos Group Inc.
//
// SPDX-License-Identifier: Apache-2.0

library gltf.extensions.omi_physics_joint;

import 'package:gltf/src/base/gltf_property.dart';
import 'package:gltf/src/ext/extensions.dart';

const String OMI_PHYSICS_JOINT = 'OMI_physics_joint';

const String LINEAR_AXES = 'linearAxes';
const String ANGULAR_AXES = 'angularAxes';
const String LOWER_LIMIT = 'lowerLimit';
const String UPPER_LIMIT = 'upperLimit';
const String STIFFNESS = 'stiffness';
const String DAMPING = 'damping';

const String CONSTRAINTS = 'constraints';
const String NODE_A = 'nodeA';
const String NODE_B = 'nodeB';

const List<String> OMI_PHYSICS_JOINT_GLTF_MEMBERS = <String>[CONSTRAINTS];
const List<String> OMI_PHYSICS_JOINT_NODE_MEMBERS = <String>[CONSTRAINTS,
    NODE_A, NODE_B];

const List<String> OMI_PHYSICS_JOINT_CONSTRAINT_MEMBERS = <String>[
  LINEAR_AXES,
  ANGULAR_AXES,
  LOWER_LIMIT,
  UPPER_LIMIT,
  STIFFNESS,
  DAMPING
];

const Extension omiPhysicsJointExtension =
    Extension(OMI_PHYSICS_JOINT, <Type, ExtensionDescriptor>{
  Gltf: ExtensionDescriptor(OmiPhysicsJointGltf.fromMap),
  Node: ExtensionDescriptor(OmiPhysicsJointNode.fromMap)
});

// The document-level extension that holds a list of constraints.
class OmiPhysicsJointGltf extends GltfProperty {
  SafeList<OmiPhysicsJointConstraint> constraints;

  OmiPhysicsJointGltf._(
      this.constraints, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static OmiPhysicsJointGltf fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, OMI_PHYSICS_JOINT_GLTF_MEMBERS, context);
    }

    SafeList<OmiPhysicsJointConstraint> constraints;
    final constraintMaps = getMapList(map, CONSTRAINTS, context);
    if (constraintMaps != null) {
      constraints = SafeList<OmiPhysicsJointConstraint>(
          constraintMaps.length, CONSTRAINTS);
      context.path.add(CONSTRAINTS);
      for (var i = 0; i < constraintMaps.length; i++) {
        final constraintMap = constraintMaps[i];
        context.path.add(i.toString());
        constraints[i] = OmiPhysicsJointConstraint.fromMap(
            constraintMap, context);
        context.path.removeLast();
      }
      context.path.removeLast();
    } else {
      constraints = SafeList<OmiPhysicsJointConstraint>.empty(CONSTRAINTS);
    }

    return OmiPhysicsJointGltf._(
        constraints,
        getExtensions(map, OmiPhysicsJointGltf, context),
        getExtras(map, context));
  }

  @override
  void link(Gltf gltf, Context context) {
    if (constraints != null) {
      context.path.add(CONSTRAINTS);
      final extCollectionList = context.path.toList(growable: false);
      context.extensionCollections[constraints] = extCollectionList;
      constraints.forEachWithIndices((i, constraint) {
        context.path.add(i.toString());
        constraint.link(gltf, context);
        context.path.removeLast();
      });
      context.path.removeLast();
    }
  }
}

// The main data structure that stores joint constraint data.
class OmiPhysicsJointConstraint extends GltfChildOfRootProperty {
  final List<double> linearAxes;
  final List<double> angularAxes;
  final double lowerLimit;
  final double upperLimit;
  final double stiffness;
  final double damping;

  OmiPhysicsJointConstraint._(this.linearAxes, this.angularAxes,
      this.lowerLimit, this.upperLimit, this.stiffness, this.damping,
      String name, Map<String, Object> extensions, Object extras)
      : super(name, extensions, extras);

  static OmiPhysicsJointConstraint fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, OMI_PHYSICS_JOINT_CONSTRAINT_MEMBERS, context);
    }

    final linearAxes = getFloatList(map, LINEAR_AXES, context,
        lengthsList: const [0, 1, 2, 3], min: 0, max: 2, def: const []);
    final angularAxes = getFloatList(map, ANGULAR_AXES, context,
        lengthsList: const [0, 1, 2, 3], min: 0, max: 2, def: const []);

    final lowerLimit = getFloat(map, LOWER_LIMIT, context, def: 0);
    final upperLimit = getFloat(map, UPPER_LIMIT, context, def: 0);
    final stiffness = getFloat(map, STIFFNESS, context,
        min: 0, def: double.infinity);
    final damping = getFloat(map, DAMPING, context, def: 1);

    if (context.validate) {
      if (linearAxes.length + angularAxes.length == 0) {
        context.addIssue(SemanticError.omiPhysicsJointConstraintNoAxes);
      }
      for (var i = 0; i < linearAxes.length; i++) {
        if (linearAxes[i].round() != linearAxes[i]) {
          context.addIssue(SchemaError.valueNotInList, name: LINEAR_AXES,
              args: [linearAxes[i], [0, 1, 2]]);
        }
      }
      for (var i = 0; i < angularAxes.length; i++) {
        if (angularAxes[i].round() != angularAxes[i]) {
          context.addIssue(SchemaError.valueNotInList, name: ANGULAR_AXES,
              args: [angularAxes[i], [0, 1, 2]]);
        }
      }
      if (lowerLimit > upperLimit) {
        context.addIssue(SemanticError.omiPhysicsJointConstraintInvalidLimits);
      }
    }

    return OmiPhysicsJointConstraint._(
        linearAxes,
        angularAxes,
        lowerLimit,
        upperLimit,
        stiffness,
        damping,
        getName(map, context),
        getExtensions(map, OmiPhysicsJointConstraint, context),
        getExtras(map, context));
  }
}

// The node-level extension that references document-level constraints by index.
class OmiPhysicsJointNode extends GltfProperty {
  List<int> constraintIndices;

  OmiPhysicsJointNode._(
      this.constraintIndices, Map<String, Object> extensions, Object extras)
      : super(extensions, extras);

  static OmiPhysicsJointNode fromMap(
      Map<String, Object> map, Context context) {
    if (context.validate) {
      checkMembers(map, OMI_PHYSICS_JOINT_NODE_MEMBERS, context);
    }

    return OmiPhysicsJointNode._(
        getIndicesList(map, CONSTRAINTS, context),
        getExtensions(map, OmiPhysicsJointNode, context),
        getExtras(map, context));
  }

  @override
  void link(Gltf gltf, Context context) {
    if (!context.validate) {
      return;
    }
    final jointsExtension = gltf.extensions[omiPhysicsJointExtension.name];
    if (jointsExtension is OmiPhysicsJointGltf) {
      // Mark the constraints that this node references as used.
      for (var i = 0; i < constraintIndices.length; i++) {
        final index = constraintIndices[i];
        if (index < 0 || index >= jointsExtension.constraints.length) {
          context.addIssue(LinkError.unresolvedReference,
              name: CONSTRAINTS, args: [index]);
        } else {
          jointsExtension.constraints[index].markAsUsed();
        }
      }
      // Get the glTF node that this physics joint is attached to.
      final path = context.path;
      if (path.length < 2 || path[0] != 'nodes') {
        return;
      }
      final nodeIndex = int.tryParse(path[1]);
      if (nodeIndex == null) {
        return;
      }
      final node = gltf.nodes[nodeIndex];
      // Ensure that the joint is not on the same glTF node as a mesh or camera.
      if (node.mesh != null) {
        context.addIssue(SemanticError.sharesNodeWith,
            args: ['A physics joint', 'a mesh']);
      }
      if (node.camera != null) {
        context.addIssue(SemanticError.sharesNodeWith,
            args: ['A physics joint', 'a camera']);
      }
      if (node.extensions.containsKey('OMI_collider')) {
        context.addIssue(SemanticError.sharesNodeWith,
            args: ['A physics joint', 'a collider']);
      }
      if (node.extensions.containsKey('OMI_physics_body')) {
        context.addIssue(SemanticError.sharesNodeWith,
            args: ['A physics joint', 'a physics body']);
      }
    } else {
      context.addIssue(SchemaError.unsatisfiedDependency,
          args: ['/$EXTENSIONS/${omiPhysicsJointExtension.name}']);
    }
  }
}
