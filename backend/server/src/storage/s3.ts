import { S3Client, CreateBucketCommand, DeleteBucketCommand, PutObjectCommand, DeleteObjectCommand, PutBucketAclCommand, HeadObjectCommand } from '@aws-sdk/client-s3';
import { Storage } from "./storage.js";
import logger from '../log.js';

export class S3Storage implements Storage {
    private bucket: string;
    private cdnPrefix: string;
    private s3Client: S3Client;

    constructor(options: { accessKeyId: string, secretAccessKey: string, region: string, bucketName: string, cdnPrefix: string }) {
        this.bucket = options.bucketName;
        this.cdnPrefix = options.cdnPrefix;
        this.s3Client = new S3Client({
            region: options.region,
            credentials: {
                accessKeyId: options.accessKeyId,
                secretAccessKey: options.secretAccessKey
            }
        });
    }

    public async createBucket(options?: { publicallyReadable: boolean }): Promise<void> {
        try {
            await this.s3Client.send(new CreateBucketCommand({ Bucket: this.bucket }));
            if (options?.publicallyReadable) {
                await this.s3Client.send(new PutBucketAclCommand({ Bucket: this.bucket, ACL: 'public-read' }));
            }
        } catch (e) {
            if ((e as any)?.name === 'BucketAlreadyOwnedByYou') {
                logger.info("Bucket already exists");
                return;
            }
            throw e;
        }
    }

    public async deleteBucket(): Promise<void> {
        await this.s3Client.send(new DeleteBucketCommand({ Bucket: this.bucket }));
    }

    public async upload(key: string, data: Buffer): Promise<string> {
        try {
            await this.s3Client.send(new HeadObjectCommand({
                Bucket: this.bucket,
                Key: key,
            }));
            return this.urlForKey(key);
        } catch (error: any) {
            if (error.name === 'NotFound') {
                await this.s3Client.send(new PutObjectCommand({
                    Bucket: this.bucket,
                    Key: key,
                    Body: data,
                }));
                return this.urlForKey(key);
            } else {
                throw error;
            }
        }
    }

    public async delete(key: string): Promise<void> {
        await this.s3Client.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
    }

    public urlForKey(key: string): string {
        return `${this.cdnPrefix}/${key}`;
    }
}
