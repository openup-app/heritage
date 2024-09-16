import { getFirestore, Firestore } from "firebase-admin/firestore";

export class Database {
  private firestore: Firestore;

  constructor() {
    this.firestore = getFirestore();
  }

  public async getDatabaseName(): Promise<string> {
    return this.firestore.databaseId;
  }
}
