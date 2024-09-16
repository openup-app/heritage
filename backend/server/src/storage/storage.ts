export interface Storage {
    upload(key: string, data: Buffer): Promise<string>;
    delete(key: string): Promise<void>;
    urlForKey(key: string): string;
}