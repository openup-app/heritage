import { getFirestore, Firestore, DocumentReference, Transaction } from "firebase-admin/firestore";
import shortUUID from "short-uuid";
import { z } from "zod";
import logger from "./log.js";
import { storage } from "firebase-admin";

export class Database {
  private firestore: Firestore;

  constructor() {
    this.firestore = getFirestore();
  }

  public async addConnection(sourceId: Id, firstName: string, lastName: string, gender: Gender, relationship: Relationship, creatorId: Id): Promise<{ id: Id, people: Person[] } | undefined> {
    return this.firestore.runTransaction(async (t: Transaction) => {
      const sourceRef = this.personRef(sourceId);
      const sourceDoc = await t.get(sourceRef);
      const source = personSchema.parse(sourceDoc.data());
      const createdPeople: Person[] = [];
      const updatedPeople: Person[] = [];

      // Invariants
      if (relationship === "parent") {
        if (source.parents.length !== 0) {
          return undefined;
        }
      } else if (relationship === "spouse") {
        // TODO: Remove restriction when this is better understood
        if (source.spouses.length > 0) {
          return undefined;
        }
      }

      // TODO: Don't allow adding of any spouse's family

      const newPerson = this.newEmptyPerson(gender, creatorId);
      newPerson.profile.firstName = firstName;
      newPerson.profile.lastName = lastName;
      createdPeople.push(newPerson);

      if (relationship == "parent") {
        const spouse = this.newEmptyPerson(newPerson.profile.gender === "male" ? "female" : "male", creatorId);
        createdPeople.push(spouse);

        spouse.spouses.push(newPerson.id);
        newPerson.spouses.push(spouse.id);
        spouse.children.push(sourceId);
        newPerson.children.push(sourceId);

        source.parents.push(newPerson.id, spouse.id);
        updatedPeople.push(source);
        t.update(sourceRef, source);
      } else if (relationship == "sibling") {
        let parent1: Person;
        let parent2: Person;
        var didCreateParents = false;
        if (source.parents.length === 0) {
          didCreateParents = true;

          parent1 = this.newEmptyPerson("male", creatorId);
          parent2 = this.newEmptyPerson("female", creatorId);
          createdPeople.push(parent1, parent2);

          parent1.spouses.push(parent2.id);
          parent2.spouses.push(parent1.id);
          parent1.children.push(sourceId);
          parent2.children.push(sourceId);

          source.parents.push(parent1.id, parent2.id);
          updatedPeople.push(source);
          t.update(sourceRef, source);
        } else {
          const [parent1Snapshot, parent2Snapshot] = await t.getAll(...source.parents.map(e => this.personRef(e)));
          if (!parent1Snapshot.exists || !parent2Snapshot.exists) {
            throw "Missing parent";
          }
          parent1 = personSchema.parse(parent1Snapshot.data());
          parent2 = personSchema.parse(parent2Snapshot.data());
        }

        parent1.children.push(newPerson.id);
        parent2.children.push(newPerson.id);
        if (!didCreateParents) {
          updatedPeople.push(parent1);
          updatedPeople.push(parent2);
          t.update(this.personRef(parent1.id), parent1);
          t.update(this.personRef(parent2.id), parent2);
        }

        newPerson.parents.push(parent1.id, parent2.id);
      } else if (relationship == "child") {
        let spouse: Person;
        var didCreateSpouse = false;
        if (source.spouses.length === 0) {
          didCreateSpouse = true;
          spouse = this.newEmptyPerson(source.profile.gender === "male" ? "female" : "male", creatorId);
          createdPeople.push(spouse);

          spouse.spouses.push(sourceId);
          source.spouses.push(spouse.id);
        } else {
          const spouseRef = this.personRef(source.spouses[0]);
          const spouseSnapshot = await t.get(spouseRef);
          spouse = personSchema.parse(spouseSnapshot.data());
        }
        spouse.children.push(newPerson.id);
        source.children.push(newPerson.id);
        updatedPeople.push(spouse);
        updatedPeople.push(source);
        t.update(sourceRef, source);
        if (!didCreateSpouse) {
          t.update(this.personRef(spouse.id), spouse);
        }

        newPerson.parents.push(sourceId, spouse.id);
      } else if (relationship == "spouse") {
        newPerson.spouses.push(sourceId);

        source.spouses.push(newPerson.id);
        updatedPeople.push(source);
        t.update(sourceRef, source);
      }

      for (const person of createdPeople) {
        t.create(this.personRef(person.id), person);
      }

      return { id: newPerson.id, people: [...createdPeople, ...updatedPeople] };
    });
  }

  public async createRootPerson(firstName: string, lastName: string, gender: Gender): Promise<Person> {
    const person = this.newEmptyPerson(gender, "root");
    person.profile.firstName = firstName;
    person.profile.lastName = lastName;
    person.ownedBy = person.id;
    await this.personRef(person.id).create(person);
    return person;
  }

  public async getLimitedGraph(id: Id): Promise<Person[]> {
    return this.fetchUpToDistance(id, { maxDistance: 3, traverseSilbingsChildrenAfterRelativeLevel: -2 });
  }

  public async getPerson(id: Id): Promise<Person> {
    const people = await this.getPeople([id]);
    if (people.length === 0) {
      throw "Unable to fetch person";
    }
    return people[0];
  }

  public async getPeople(ids: Id[]): Promise<Person[]> {
    const personRefs = ids.map(e => this.personRef(e));
    const snapshot = await this.firestore.getAll(...personRefs);
    const people: Person[] = [];
    for (const doc of snapshot) {
      try {
        const data = doc.data() ?? {};
        people.push(personSchema.parse(data));
      } catch (e) {
        logger.warn(`Failed to get or parse person ${doc.id}`);
      }
    }
    return people;
  }

  public async getRoots(): Promise<Person[]> {
    const snapshot = await this.firestore.collection("people").where("addedBy", "==", "root").get();
    const people: Person[] = [];
    for (const doc of snapshot.docs) {
      try {
        const data = doc.data() ?? {};
        people.push(personSchema.parse(data));
      } catch (e) {
        logger.warn(`Failed to get or parse person ${doc.id}`);
      }
    }
    return people;
  }

  public async deletePerson(id: Id): Promise<Person[]> {
    return this.firestore.runTransaction(async (t: Transaction) => {
      const personSnapshot = await t.get(this.personRef(id));
      const person = personSchema.parse(personSnapshot.data());
      if (person.ownedBy) {
        throw "Unable to delete an owned person";
      }

      if (person.children.length > 0) {
        throw "Unable to delete a person with children";
      }

      const hasParents = person.parents.length > 0;
      const hasSpouses = person.spouses.length > 0;
      if (hasParents && hasSpouses) {
        throw "Unable to delete person with more than one link";
      }

      const updatedPeople: Person[] = []
      if (hasParents) {
        const parentRefs = person.parents.map(id => this.personRef(id));
        const parentSnapshots = await t.getAll(...parentRefs);
        const parents = parentSnapshots.map(s => personSchema.parse(s.data()));
        for (const parent of parents) {
          arrayRemove(parent.children, id);
          updatedPeople.push(parent);
        }
      } else if (hasSpouses) {
        const spouseRefs = person.spouses.map(id => this.personRef(id));
        const spouseSnapshots = await t.getAll(...spouseRefs);
        const spouses = spouseSnapshots.map(s => personSchema.parse(s.data()));
        for (const spouse of spouses) {
          arrayRemove(spouse.spouses, id);
          updatedPeople.push(spouse);
        }
      }
      for (const person of updatedPeople) {
        t.update(this.personRef(person.id), person);
      }
      t.delete(this.personRef(id));
      return updatedPeople;
    });
  }

  public async fetchUpToDistance(id: Id, options: { maxDistance: number, traverseSilbingsChildrenAfterRelativeLevel: number }): Promise<Person[]> {
    const visited = new Set<Id>();
    const spouses = new Set<Id>();
    const bloodRelatives = new Set<Id>();
    const fringe: { id: Id; relativeLevel: number, shouldTraverse: boolean }[] = [{ id, relativeLevel: 0, shouldTraverse: true, }];
    const output: Person[] = [];

    bloodRelatives.add(id);
    while (fringe.length > 0) {
      // Fetch fringe in a single request
      const currentFringe = fringe.splice(0, fringe.length);
      const fringeIds = currentFringe.map(f => f.id);
      const fringeIdToLevel = new Map<Id, number>(currentFringe.map(f => [f.id, f.relativeLevel]));
      const fringeIdToShouldTraverse = new Map<Id, boolean>(currentFringe.map(f => [f.id, f.shouldTraverse]));
      const personRefs = fringeIds.map(id => this.personRef(id));
      const snapshots = await this.firestore.getAll(...personRefs);

      for (const snapshot of snapshots) {
        if (!snapshot.exists) {
          continue;
        }

        const person = personSchema.parse(snapshot.data());
        const id = snapshot.id;
        const relativeLevel = fringeIdToLevel.get(id)!;
        const shouldTraverse = fringeIdToShouldTraverse.get(id)!;

        if (visited.has(id)) {
          continue;
        }

        visited.add(id);
        output.push(person);

        // Traversal limited at out of family spouses and max depth
        if ((spouses.has(id) && !bloodRelatives.has(id)) || relativeLevel >= options.maxDistance) {
          continue;
        }

        // Next
        if (shouldTraverse) {
          for (const id of person.parents) {
            if (!visited.has(id)) {
              fringe.push({
                id: id,
                relativeLevel: relativeLevel - 1,
                shouldTraverse: true,
              });
            }
          }
          person.parents.forEach(r => bloodRelatives.add(r));

          for (const id of person.children) {
            if (!visited.has(id)) {
              fringe.push({
                id: id,
                relativeLevel: relativeLevel + 1,
                shouldTraverse: relativeLevel >= options.traverseSilbingsChildrenAfterRelativeLevel
              });
            }
          }
          person.children.forEach(r => bloodRelatives.add(r));
        }

        for (const spouseId of person.spouses) {
          if (!visited.has(spouseId)) {
            fringe.push({ id: spouseId, relativeLevel: relativeLevel, shouldTraverse: false });
          }
        }

        if (person.spouses.length > 0) {
          for (const spouseId of person.spouses) {
            spouses.add(spouseId);
          }
        }
      }
    }

    return output;
  }

  public async updateProfile(id: Id, profile: Profile): Promise<Person> {
    const personRef = this.personRef(id);
    await personRef.set({ "profile": profile }, { merge: true });
    const snapshot = await personRef.get();
    const data = snapshot.data();
    return personSchema.parse(data);
  }

  public async updateOwnership(id: Id, newOwnerId: Id): Promise<Person> {
    const personRef = this.personRef(id);
    await personRef.update({ "ownedBy": id });
    const snapshot = await personRef.get();
    const data = snapshot.data();
    return personSchema.parse(data);
  }


  private newEmptyPerson(gender: Gender, creatorId: Id): Person {
    return {
      "id": shortUUID.generate(),
      "parents": [],
      "spouses": [],
      "children": [],
      "addedBy": creatorId,
      "ownedBy": null,
      "createdAt": new Date().toISOString(),
      "profile": {
        "firstName": "Unknown",
        "lastName": "",
        "gender": gender,
        "photoKey": null,
        "galleryKeys": [],
        "birthday": null,
        "deathday": null,
        "birthplace": "",
        "occupation": "",
        "hobbies": "",
      }
    }
  }

  private personRef(id: Id): DocumentReference {
    return this.firestore.collection("people").doc(id);
  }
}

function arrayRemove<T>(array: T[], key: T): boolean {
  const index = array.indexOf(key, 0);
  if (index < 0) {
    return false;
  }
  array.splice(index, 1);
  return true;
}

const idSchema = z.string();

export const genderSchema = z.enum(["male", "female"]);

export const relationshipSchema = z.enum(["parent", "sibling", "spouse", "child"]);

export const profileSchema = z.object({
  firstName: z.string(),
  lastName: z.string(),
  gender: genderSchema,
  photoKey: z.string().nullable(),
  galleryKeys: z.array(z.string()),
  birthday: z.string().nullable(),
  deathday: z.string().nullable(),
  birthplace: z.string(),
  occupation: z.string(),
  hobbies: z.string(),
});

const personSchema = z.object({
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

export type Person = z.infer<typeof personSchema>;
