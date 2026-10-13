import type { WorkerRequest, WorkerResponse } from '../types.ts';
import { SimulationEngine } from './engine.ts';
import { createSolarSystem } from '../presets.ts';

const engine = new SimulationEngine(createSolarSystem());
const scope = self as unknown as { onmessage: ((event: MessageEvent<WorkerRequest>) => void) | null; postMessage: (response: WorkerResponse) => void };
scope.onmessage = ({ data }) => {
  const requestId = data?.requestId;
  try {
    if (!Number.isSafeInteger(requestId)) throw new Error('Invalid worker request ID.');
    let state;
    switch (data.type) {
      case 'load': state = engine.load(data.state); break;
      case 'advance': state = engine.advance(data.seconds, data.maxSteps); break;
      case 'edit': state = engine.edit(data.id, data.patch); break;
      case 'add': state = engine.add(data.body); break;
      case 'remove': state = engine.remove(data.id); break;
      case 'snapshot': state = engine.snapshot(); break;
      default: throw new Error('Unknown worker request.');
    }
    scope.postMessage({ requestId, state });
  } catch (error) {
    scope.postMessage({ requestId: Number.isSafeInteger(requestId) ? requestId : -1,
      error: error instanceof Error ? error.message : 'Physics worker could not process this request.' });
  }
};
