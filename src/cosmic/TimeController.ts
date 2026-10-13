import type { SimulationState } from './types.ts';

export const TIME_SPEEDS: ReadonlyArray<Readonly<{ value: number; label: string }>> = Object.freeze([
  { value: 1, label: '1 giây / giây' },
  { value: 60, label: '1 phút / giây' },
  { value: 3600, label: '1 giờ / giây' },
  { value: 86400, label: '1 ngày / giây' },
  { value: 604800, label: '1 tuần / giây' },
  { value: 2592000, label: '30 ngày / giây' },
  { value: 31557600, label: '1 năm / giây' },
].map((speed) => Object.freeze(speed)));

const MAX_HISTORY = 90;
const MAX_REAL_DELTA = 5;

/** Requests simulation time without advancing its clock outside the physics engine. */
export class TimeController {
  running = true;
  speed = 86400;
  // JSON strings are immutable and never retain references to worker/UI state.
  private history: Array<{ snapshot: string; physicalKey: string }> = [];
  private pendingSeconds = 0;

  requestSeconds(realDelta: number): number {
    if (!this.running || !Number.isFinite(realDelta) || realDelta <= 0
      || !Number.isFinite(this.speed) || this.speed <= 0) return 0;
    // Visibility changes reset the caller's clock; bound debugger/stall catch-up.
    return Math.min(realDelta, MAX_REAL_DELTA) * this.speed;
  }

  accumulate(realDelta: number): void {
    if (!this.running) {
      this.discardPending();
      return;
    }
    const seconds = this.requestSeconds(realDelta);
    if (seconds <= 0) return;
    // Accumulate while the worker is busy, with a bounded five-second backlog.
    const maximumPending = Math.max(this.speed * 5, 1);
    this.pendingSeconds = Math.min(this.pendingSeconds + seconds, maximumPending);
  }

  takeSeconds(): number {
    if (!this.running) {
      this.discardPending();
      return 0;
    }
    const seconds = this.pendingSeconds;
    this.discardPending();
    return seconds;
  }

  discardPending(): void {
    this.pendingSeconds = 0;
  }

  checkpoint(state: SimulationState): void {
    // Loading a snapshot recomputes diagnostics. That must not create a second
    // checkpoint for the same physical state or prevent further rewinds.
    const { diagnostics: _diagnostics, ...physicalState } = state;
    const physicalKey = JSON.stringify(physicalState);
    if (this.history.at(-1)?.physicalKey === physicalKey) return;
    const snapshot = JSON.stringify(state);
    this.history.push({ snapshot, physicalKey });
    if (this.history.length > MAX_HISTORY) this.history.shift();
  }

  rewind(): SimulationState | null {
    // The latest checkpoint represents the current state, not a rewind target.
    if (this.history.length < 2) return null;
    this.history.pop();
    return JSON.parse(this.history[this.history.length - 1].snapshot) as SimulationState;
  }

  clear(state?: SimulationState): void {
    this.history = [];
    this.discardPending();
    if (state) this.checkpoint(state);
  }
}
