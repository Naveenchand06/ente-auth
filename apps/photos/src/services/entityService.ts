import { getToken } from 'utils/common/key';
import localForage from 'utils/storage/localForage';
import HTTPService from './HTTPService';
import { getEndpoint } from 'utils/common/apiUtil';
import { logError } from 'utils/sentry';
import ComlinkCryptoWorker from 'utils/comlink/ComlinkCryptoWorker';
import { getActualKey } from 'utils/common/key';
import {
    EntityType,
    Entity,
    EncryptedEntityKey,
    EntityKey,
    EntitySyncDiffResponse,
    EncryptedEntity,
} from 'types/entity';
import { getLatestVersionEntities } from 'utils/entity';

const ENDPOINT = getEndpoint();

const DIFF_LIMIT = 500;

const ENTITY_TABLES: Record<EntityType, string> = {
    [EntityType.LOCATION_TAG]: 'location_tags',
};

const ENTITY_SYNC_TIME_TABLES: Record<EntityType, string> = {
    [EntityType.LOCATION_TAG]: 'location_tags_time',
};

const getLocalEntity = async <T>(type: EntityType) => {
    const entities: Array<Entity<T>> =
        (await localForage.getItem<Entity<T>[]>(ENTITY_TABLES[type])) || [];
    return entities;
};

const getEntityLastSyncTime = async (type: EntityType) => {
    return (
        (await localForage.getItem<number>(ENTITY_SYNC_TIME_TABLES[type])) ?? 0
    );
};

const getEntityKey = async (type: EntityType) => {
    try {
        const token = getToken();
        if (!token) {
            return;
        }
        const resp = await HTTPService.get(
            `${ENDPOINT}/user-entity/key`,
            {
                type,
            },
            {
                'X-Auth-Token': token,
            }
        );
        const encryptedEntityKey: EncryptedEntityKey = resp.data;
        const worker = await ComlinkCryptoWorker.getInstance();
        const masterKey = await getActualKey();
        const { encryptedKey, header, ...rest } = encryptedEntityKey;
        const decryptedData = await worker.decryptB64(
            encryptedKey,
            header,
            masterKey
        );
        return { data: decryptedData, ...rest } as EntityKey;
    } catch (e) {
        logError(e, 'Get entity key failed');
        throw e;
    }
};

export const getLatestEntities = async <T>(type: EntityType) => {
    try {
        await syncEntity<T>(type);
        return await getLocalEntity<T>(type);
    } catch (e) {
        logError(e, 'Sync entities failed');
        throw e;
    }
};

export const syncEntities = async () => {
    try {
        await syncEntity(EntityType.LOCATION_TAG);
    } catch (e) {
        logError(e, 'Sync entities failed');
        throw e;
    }
};

const syncEntity = async <T>(type: EntityType) => {
    try {
        let entities = await getLocalEntity(type);
        let syncTime = await getEntityLastSyncTime(type);
        let response: EntitySyncDiffResponse;
        do {
            response = await getEntityDiff(type, syncTime);
            if (!response.diff?.length) {
                return;
            }

            const entityKey = await getEntityKey(type);
            const newDecryptedEntities: Array<Entity<T>> = await Promise.all(
                response.diff.map(async (entity: EncryptedEntity) => {
                    if (entity.isDeleted) {
                        // This entry is deleted, so we don't need to decrypt it, just return it as is
                        // as unknown as EntityData is a hack to get around the type system
                        return entity as unknown as Entity<T>;
                    }
                    const { encryptedData, header, ...rest } = entity;
                    const worker = await ComlinkCryptoWorker.getInstance();
                    const decryptedData = await worker.decryptMetadata(
                        encryptedData,
                        header,
                        entityKey.data
                    );
                    return {
                        ...rest,
                        data: decryptedData,
                    } as Entity<T>;
                })
            );

            entities = getLatestVersionEntities([
                ...entities,
                ...newDecryptedEntities,
            ]);

            const nonDeletedEntities = entities.filter(
                (entity) => !entity.isDeleted
            );

            if (response.diff.length) {
                syncTime = response.diff.slice(-1)[0].updatedAt;
            }
            await localForage.setItem(ENTITY_TABLES[type], nonDeletedEntities);
            await localForage.setItem(ENTITY_SYNC_TIME_TABLES[type], syncTime);
        } while (response.hasMore);
    } catch (e) {
        logError(e, 'Sync entity failed');
    }
};

const getEntityDiff = async (
    type: EntityType,
    time: number
): Promise<EntitySyncDiffResponse> => {
    try {
        const token = getToken();
        if (!token) {
            return;
        }
        const resp = await HTTPService.get(
            `${ENDPOINT}/user-entity/entity/diff`,
            {
                sinceTime: time,
                type,
                limit: DIFF_LIMIT,
            },
            {
                'X-Auth-Token': token,
            }
        );

        return resp.data;
    } catch (e) {
        logError(e, 'Get entity diff failed');
        throw e;
    }
};
