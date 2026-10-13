import type { SimulationState } from './types.ts';
import { validateState } from './physics/engine.ts';

const DATABASE_NAME = 'cosmic-sandbox';
const DATABASE_VERSION = 1;
const STORE_NAME = 'simulations';
const LATEST_KEY = 'latest';
const MAX_JSON_BYTES = 2 * 1024 * 1024;

function checkSize(text: string): void {
  // Reject oversized input before parsing it or creating an IndexedDB transaction.
  if (text.length > MAX_JSON_BYTES || new TextEncoder().encode(text).byteLength > MAX_JSON_BYTES) {
    throw new Error('Tệp mô phỏng vượt quá giới hạn 2 MB. Hãy giảm số vật thể.');
  }
}

function storageError(error: unknown): Error {
  if (error instanceof Error && error.name === 'QuotaExceededError') {
    return new Error('Bộ nhớ trình duyệt đã đầy. Hãy xuất JSON hoặc giải phóng dung lượng rồi lưu lại.');
  }
  return new Error('Không thể truy cập bộ nhớ mô phỏng. Hãy cho phép lưu trữ trên trình duyệt hoặc dùng xuất/nhập JSON.');
}

/** Save one complete simulation locally; JSON files provide a portable backup. */
export class SaveLoadManager {
  private databasePromise: Promise<IDBDatabase> | null = null;

  exportJSON(state: SimulationState): string {
    const json = JSON.stringify(validateState(state), null, 2);
    checkSize(json);
    return json;
  }

  importJSON(text: string): SimulationState {
    if (typeof text !== 'string') throw new Error('Dữ liệu mô phỏng phải là văn bản JSON.');
    checkSize(text);
    let input: unknown;
    try {
      input = JSON.parse(text);
    } catch {
      throw new Error('Tệp JSON không hợp lệ. Hãy chọn tệp mô phỏng đã xuất.');
    }
    return validateState(input);
  }

  async save(state: SimulationState): Promise<void> {
    const json = this.exportJSON(state);
    const database = await this.openDatabase();
    await new Promise<void>((resolve, reject) => {
      try {
        const transaction = database.transaction(STORE_NAME, 'readwrite');
        const request = transaction.objectStore(STORE_NAME).put(json, LATEST_KEY);
        transaction.oncomplete = () => resolve();
        transaction.onabort = () => reject(storageError(request.error ?? transaction.error));
      } catch (error) {
        reject(storageError(error));
      }
    });
  }

  async load(): Promise<SimulationState | null> {
    const database = await this.openDatabase();
    const saved = await new Promise<unknown>((resolve, reject) => {
      try {
        const transaction = database.transaction(STORE_NAME, 'readonly');
        const request = transaction.objectStore(STORE_NAME).get(LATEST_KEY);
        transaction.oncomplete = () => resolve(request.result);
        transaction.onabort = () => reject(storageError(request.error ?? transaction.error));
      } catch (error) {
        reject(storageError(error));
      }
    });
    if (saved === undefined) return null;
    if (typeof saved !== 'string') {
      throw new Error('Bản lưu trong trình duyệt không hợp lệ. Hãy nhập một tệp JSON dự phòng.');
    }
    return this.importJSON(saved);
  }

  private openDatabase(): Promise<IDBDatabase> {
    if (this.databasePromise) return this.databasePromise;
    this.databasePromise = new Promise<IDBDatabase>((resolve, reject) => {
      let request: IDBOpenDBRequest;
      try {
        if (typeof indexedDB === 'undefined') {
          reject(new Error('Trình duyệt không hỗ trợ IndexedDB. Hãy dùng xuất/nhập JSON hoặc mở bằng trình duyệt hiện đại.'));
          return;
        }
        request = indexedDB.open(DATABASE_NAME, DATABASE_VERSION);
      } catch (error) {
        reject(storageError(error));
        return;
      }
      let abandoned = false;
      request.onupgradeneeded = () => {
        const database = request.result;
        if (!database.objectStoreNames.contains(STORE_NAME)) database.createObjectStore(STORE_NAME);
      };
      request.onblocked = () => {
        abandoned = true;
        reject(new Error('Bộ nhớ mô phỏng đang bị khóa. Hãy đóng các thẻ COSMIC SANDBOX khác rồi thử lại.'));
      };
      request.onerror = () => reject(storageError(request.error));
      request.onsuccess = () => {
        const database = request.result;
        if (abandoned) {
          database.close();
          return;
        }
        database.onversionchange = () => {
          database.close();
          this.databasePromise = null;
        };
        resolve(database);
      };
    }).catch((error: unknown) => {
      this.databasePromise = null;
      throw error;
    });
    return this.databasePromise;
  }
}
