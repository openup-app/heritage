import { getFirestore, Firestore, DocumentReference, Transaction } from "firebase-admin/firestore";
import shortUUID from "short-uuid";
import { z } from "zod";
import logger from "./log.js";

export class Database {
  private firestore: Firestore;

  constructor() {
    this.firestore = getFirestore();
  }

  public async addConnection(sourceId: Id, name: string, gender: Gender, relationship: Relationship, creatorId: Id): Promise<Node[]> {
    return this.firestore.runTransaction(async (t: Transaction) => {
      const sourceRef = this.nodeRef(sourceId);
      const sourceDoc = await t.get(sourceRef);
      const sourceNode = nodeSchema.parse(sourceDoc.data());
      const createdNodes: Node[] = [];
      const updatedNodes: Node[] = [];

      // Invariants
      if (relationship === "parent") {
        if (sourceNode.parents.length !== 0) {
          return [];
        }
      } else if (relationship === "spouse") {
        // TODO: Remove restriction when this is better understood
        if (sourceNode.spouses.length > 0) {
          return [];
        }
      }

      // TODO: Don't allow adding of any spouse's family

      const node = this.newEmptyNode(gender, creatorId);
      node.profile.name = name;
      createdNodes.push(node);

      if (relationship == "parent") {
        const spouseNode = this.newEmptyNode(node.profile.gender === "male" ? "female" : "male", creatorId);
        createdNodes.push(spouseNode);

        spouseNode.spouses.push(node.id);
        node.spouses.push(spouseNode.id);
        spouseNode.children.push(sourceId);
        node.children.push(sourceId);

        sourceNode.parents.push(node.id, spouseNode.id);
        updatedNodes.push(sourceNode);
        t.update(sourceRef, sourceNode);
      } else if (relationship == "sibling") {
        let parent1Node: Node;
        let parent2Node: Node;
        var didCreateParents = false;
        if (sourceNode.parents.length === 0) {
          didCreateParents = true;

          parent1Node = this.newEmptyNode("male", creatorId);
          parent2Node = this.newEmptyNode("female", creatorId);
          createdNodes.push(parent1Node, parent2Node);

          parent1Node.spouses.push(parent2Node.id);
          parent2Node.spouses.push(parent1Node.id);
          parent1Node.children.push(sourceId);
          parent2Node.children.push(sourceId);

          sourceNode.parents.push(parent1Node.id, parent2Node.id);
          updatedNodes.push(sourceNode);
          t.update(sourceRef, sourceNode);
        } else {
          const [parent1Snapshot, parent2Snapshot] = await t.getAll(...sourceNode.parents.map(e => this.nodeRef(e)));
          if (!parent1Snapshot.exists || !parent2Snapshot.exists) {
            throw "Missing parent";
          }
          parent1Node = nodeSchema.parse(parent1Snapshot.data());
          parent2Node = nodeSchema.parse(parent2Snapshot.data());
        }

        parent1Node.children.push(node.id);
        parent2Node.children.push(node.id);
        if (!didCreateParents) {
          updatedNodes.push(parent1Node);
          updatedNodes.push(parent2Node);
          t.update(this.nodeRef(parent1Node.id), parent1Node);
          t.update(this.nodeRef(parent2Node.id), parent2Node);
        }

        node.parents.push(parent1Node.id, parent2Node.id);
      } else if (relationship == "child") {
        let spouseNode: Node;
        var didCreateSpouse = false;
        if (sourceNode.spouses.length === 0) {
          didCreateSpouse = true;
          spouseNode = this.newEmptyNode(sourceNode.profile.gender === "male" ? "female" : "male", creatorId);
          createdNodes.push(spouseNode);

          spouseNode.spouses.push(sourceId);
          sourceNode.spouses.push(spouseNode.id);
        } else {
          const spouseRef = this.nodeRef(sourceNode.spouses[0]);
          const spouseSnapshot = await t.get(spouseRef);
          spouseNode = nodeSchema.parse(spouseSnapshot.data());
        }
        spouseNode.children.push(node.id);
        sourceNode.children.push(node.id);
        updatedNodes.push(spouseNode);
        updatedNodes.push(sourceNode);
        t.update(sourceRef, sourceNode);
        if (!didCreateSpouse) {
          t.update(this.nodeRef(spouseNode.id), spouseNode);
        }

        node.parents.push(sourceId, spouseNode.id);
      } else if (relationship == "spouse") {
        node.spouses.push(sourceId);

        sourceNode.spouses.push(node.id);
        updatedNodes.push(sourceNode);
        t.update(sourceRef, sourceNode);
      }

      for (const node of createdNodes) {
        t.create(this.nodeRef(node.id), node);
      }

      return [...createdNodes, ...updatedNodes];
    });
  }

  public async createRootNode(name: string, gender: Gender): Promise<Node> {
    const node = this.newEmptyNode(gender, "root");
    node.profile.name = name;
    node.ownedBy = node.id;
    await this.nodeRef(node.id).create(node);
    return node;
  }

  public async getLimitedGraph(id: Id): Promise<Node[]> {
    return this.fetchUpToDistance(id, { maxDistance: 3, noChildrenOfSiblingsOfAncestorDistance: 2 });
  }

  public async getNode(id: Id): Promise<Node> {
    const nodes = await this.getNodes([id]);
    if (nodes.length === 0) {
      throw "Unable to fetch node";
    }
    return nodes[0];
  }

  public async getNodes(ids: Id[]): Promise<Node[]> {
    const nodeRefs = ids.map(e => this.nodeRef(e));
    const snapshot = await this.firestore.getAll(...nodeRefs);
    const nodes: Node[] = [];
    for (const doc of snapshot) {
      try {
        const data = doc.data() ?? {};
        nodes.push(nodeSchema.parse(data));
      } catch (e) {
        logger.warn(`Failed to get or parse node ${doc.id}`);
      }
    }
    return nodes;
  }

  public async getRoots(): Promise<Node[]> {
    const snapshot = await this.firestore.collection("nodes").where("addedBy", "==", "root").get();
    const nodes: Node[] = [];
    for (const doc of snapshot.docs) {
      try {
        const data = doc.data() ?? {};
        nodes.push(nodeSchema.parse(data));
      } catch (e) {
        logger.warn(`Failed to get or parse node ${doc.id}`);
      }
    }
    return nodes;
  }

  public async fetchUpToDistance(id: Id, options: { maxDistance: number, noChildrenOfSiblingsOfAncestorDistance: number }): Promise<Node[]> {
    const visited = new Set<Id>();
    const spouses = new Set<Id>();
    const fringe: { id: Id; level: number }[] = [{ id, level: 0 }];
    const output: Node[] = [];

    while (fringe.length > 0) {
      // Fetch fringe in a single request
      const currentFringe = fringe.splice(0, fringe.length);
      const fringeIds = currentFringe.map(f => f.id);
      const fringeIdToLevel = new Map<Id, number>(currentFringe.map(f => [f.id, f.level]));
      const nodeRefs = fringeIds.map(id => this.nodeRef(id));
      const snapshots = await this.firestore.getAll(...nodeRefs);

      for (const snapshot of snapshots) {
        if (!snapshot.exists) {
          continue;
        }

        const node = nodeSchema.parse(snapshot.data());
        const id = snapshot.id;
        const level = fringeIdToLevel.get(id)!;

        if (visited.has(id)) {
          continue;
        }

        visited.add(id);
        output.push(node);

        // Traversal limited at spouses and max depth
        if (spouses.has(id) || level >= options.maxDistance) {
          continue;
        }

        const neighbourIds = new Set<Id>([
          ...node.parents,
          ...node.spouses,
          ...((level < options.noChildrenOfSiblingsOfAncestorDistance) ? node.children : []),
        ]);

        // Next level fringe
        for (const neighbourId of neighbourIds) {
          if (!visited.has(neighbourId)) {
            fringe.push({ id: neighbourId, level: level + 1 });
          }
        }

        if (node.spouses.length > 0) {
          for (const spouseId of node.spouses) {
            spouses.add(spouseId);
          }
        }
      }
    }

    return output;
  }

  public async updateProfile(id: Id, profile: Profile): Promise<Node> {
    const nodeRef = this.nodeRef(id);
    await nodeRef.update({ "profile": profile });
    const snapshot = await nodeRef.get();
    const data = snapshot.data();
    return nodeSchema.parse(data);
  }

  public async updateOwnership(id: Id, newOwnerId: Id): Promise<Node> {
    const nodeRef = this.nodeRef(id);
    await nodeRef.update({ "ownedBy": id });
    const snapshot = await nodeRef.get();
    const data = snapshot.data();
    return nodeSchema.parse(data);
  }


  private newEmptyNode(gender: Gender, creatorId: Id): Node {
    return {
      "id": shortUUID.generate(),
      "parents": [],
      "spouses": [],
      "children": [],
      "addedBy": creatorId,
      "ownedBy": null,
      "createdAt": new Date().toISOString(),
      "profile": {
        "name": "Unknown",
        "gender": gender,
        "imageKey": null,
        "birthday": null,
        "deathday": null,
        "birthplace": "",
      }
    }
  }

  private nodeRef(id: Id): DocumentReference {
    return this.firestore.collection("nodes").doc(id);
  }
}

const idSchema = z.string();

export const genderSchema = z.enum(["male", "female"]);

export const relationshipSchema = z.enum(["parent", "sibling", "spouse", "child"]);

export const profileSchema = z.object({
  name: z.string(),
  gender: genderSchema,
  imageKey: z.string().nullable().optional(),
  birthday: z.string().nullable(),
  deathday: z.string().nullable(),
  birthplace: z.string(),
});

const nodeSchema = z.object({
  id: idSchema,
  parents: z.array(idSchema),
  spouses: z.array(idSchema),
  children: z.array(idSchema),
  addedBy: idSchema,
  ownedBy: idSchema.nullable(),
  createdAt: z.string(),
  profile: profileSchema,
});

type Id = z.infer<typeof idSchema>;

type Gender = z.infer<typeof genderSchema>;

type Relationship = z.infer<typeof relationshipSchema>;

export type Profile = z.infer<typeof profileSchema>;

export type Node = z.infer<typeof nodeSchema>;
