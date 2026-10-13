import type { SimulationState, WorkerRequest, WorkerResponse } from './types.ts';

type Command = WorkerRequest extends infer R ? R extends WorkerRequest ? Omit<R, 'requestId'> : never : never;
export class WorkerClient {
  private nextId = 1;
  private pending = new Map<number, { resolve: (s: SimulationState) => void; reject: (e: Error) => void }>();
  constructor(private worker: Worker) {
    worker.onmessage = ({ data }: MessageEvent<WorkerResponse>) => {
      const promise = this.pending.get(data.requestId);
      if (!promise) return;
      this.pending.delete(data.requestId);
      if (data.error || !data.state) promise.reject(new Error(data.error || 'Worker không trả về trạng thái.'));
      else promise.resolve(data.state);
    };
    worker.onerror = event => {
      for (const promise of this.pending.values()) promise.reject(new Error(event.message || 'Không thể chạy physics Worker.'));
      this.pending.clear();
    };
  }
  request(command: Command): Promise<SimulationState> {
    const requestId = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(requestId, { resolve, reject });
      this.worker.postMessage({ ...command, requestId });
    });
  }
  dispose() {
    this.worker.terminate();
    for (const promise of this.pending.values()) promise.reject(new Error('Worker đã đóng.'));
    this.pending.clear();
  }
}
