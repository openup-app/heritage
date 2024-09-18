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
      if (!sourceDoc.exists) {
        return [];
      }

      const data = sourceDoc.data() ?? {};
      const sourceNode = nodeSchema.parse(data);
      const createdNodes: Node[] = [];

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
          const spouseSnapshot = await t.get(this.nodeRef(sourceNode.spouses[0]));
          if (!spouseSnapshot.exists) {
            throw "Missing spouse";
          }
          spouseNode = nodeSchema.parse(data);
        }
        spouseNode.children.push(node.id);
        sourceNode.children.push(node.id);
        t.update(sourceRef, sourceNode);
        if (!didCreateSpouse) {
          t.update(this.nodeRef(spouseNode.id), spouseNode);
        }

        node.parents.push(sourceId, spouseNode.id);
      } else if (relationship == "spouse") {
        node.spouses.push(sourceId);

        sourceNode.spouses.push(node.id);
        t.update(sourceRef, sourceNode);
      }

      for (const node of createdNodes) {
        t.create(this.nodeRef(node.id), node);
      }

      return createdNodes;
    });
  }

  public async createRootNode(name: string, gender: Gender): Promise<Node> {
    const node = this.newEmptyNode(gender, "root");
    node.profile.name = name;
    await this.nodeRef(node.id).create(node);
    return node;
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
        "birthday": null,
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

const nodeSchema = z.object({
  id: idSchema,
  parents: z.array(idSchema),
  spouses: z.array(idSchema),
  children: z.array(idSchema),
  addedBy: idSchema,
  ownedBy: idSchema.nullable(),
  createdAt: z.string(),
  profile: z.object({
    name: z.string(),
    gender: genderSchema,
    birthday: z.string().nullable(),
  }),
});

type Id = z.infer<typeof idSchema>;

type Gender = z.infer<typeof genderSchema>;

type Relationship = z.infer<typeof relationshipSchema>;

type Node = z.infer<typeof nodeSchema>;
