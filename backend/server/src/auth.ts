import { getAuth, Auth as FirebaseAuth } from "firebase-admin/auth";

export class Auth {
    private firebaseAuth: FirebaseAuth;

    public constructor() {
        this.firebaseAuth = getAuth();
    }

    public async uidForToken(authToken: string): Promise<string | undefined> {
        try {
            const decodedToken = await this.firebaseAuth.verifyIdToken(authToken);
            return decodedToken.uid;
        } catch (e) {
            return undefined;
        }
    }

    public async isUidTokenValid(
        authToken: string,
        uid: string
    ): Promise<boolean> {
        try {
            return (await this.uidForToken(authToken)) === uid;
        } catch (e) {
            return false;
        }
    }
}
