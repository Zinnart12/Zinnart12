import * as THREE from 'three';

export class CameraRig {
  constructor(element) {
    this.element = element;
    element.tabIndex = 0;
    this.camera = new THREE.PerspectiveCamera(46, 1, 0.01, 5000);
    this.mode = 'orbit';
    this.keys = new Set();
    this.dragging = false;
    this.lastPointer = new THREE.Vector2();
    this.target = new THREE.Vector3();
    this.vector = new THREE.Vector3();
    this.rotation = new THREE.Euler(0, 0, 0, 'YXZ');
    this.forward = new THREE.Vector3();
    this.right = new THREE.Vector3();
    this.up = new THREE.Vector3(0, 1, 0);
    this.reset();
    element.addEventListener('pointerdown', event => {
      if (event.button !== 0) return;
      element.focus({ preventScroll: true });
      this.dragging = true;
      this.lastPointer.set(event.clientX, event.clientY);
      element.setPointerCapture(event.pointerId);
      element.classList.add('dragging');
    });
    element.addEventListener('pointermove', event => {
      if (!this.dragging) return;
      const dx = event.clientX - this.lastPointer.x;
      const dy = event.clientY - this.lastPointer.y;
      this.lastPointer.set(event.clientX, event.clientY);
      if (this.mode === 'orbit') {
        this.desiredTheta -= dx * 0.004;
        this.desiredPhi = THREE.MathUtils.clamp(this.desiredPhi - dy * 0.004, 0.015, Math.PI - 0.015);
      } else {
        this.yaw -= dx * 0.003;
        this.pitch = THREE.MathUtils.clamp(this.pitch - dy * 0.003, -Math.PI / 2 + 0.015, Math.PI / 2 - 0.015);
      }
    });
    const release = () => { this.dragging = false; element.classList.remove('dragging'); };
    element.addEventListener('pointerup', release);
    element.addEventListener('pointercancel', release);
    element.addEventListener('lostpointercapture', release);
    element.addEventListener('wheel', event => {
      event.preventDefault();
      if (this.mode === 'orbit') this.desiredDistance = THREE.MathUtils.clamp(this.desiredDistance * Math.exp(event.deltaY * 0.001), 2.8, 200);
      else this.flySpeed = THREE.MathUtils.clamp(this.flySpeed * Math.exp(-event.deltaY * 0.001), 0.5, 90);
    }, { passive: false });
    window.addEventListener('keydown', event => {
      if (/INPUT|SELECT|TEXTAREA|BUTTON/.test(event.target.tagName) || event.ctrlKey || event.metaKey) return;
      if (['KeyW', 'KeyA', 'KeyS', 'KeyD', 'KeyQ', 'KeyE', 'ShiftLeft', 'ShiftRight'].includes(event.code)) {
        this.keys.add(event.code);
        event.preventDefault();
      }
    });
    window.addEventListener('keyup', event => this.keys.delete(event.code));
    window.addEventListener('blur', () => { this.keys.clear(); release(); });
    document.addEventListener('visibilitychange', () => { if (document.hidden) this.keys.clear(); });
  }

  reset() {
    this.distance = this.desiredDistance = 34;
    this.theta = this.desiredTheta = 0;
    this.phi = this.desiredPhi = Math.PI / 2 - 0.13;
    this.flySpeed = 6;
    this.target.set(0, 0, 0);
    this.keys.clear();
    this.camera.position.set(0, Math.cos(this.phi) * this.distance, Math.sin(this.phi) * this.distance);
    this.camera.lookAt(this.target);
    this.syncFlyAngles();
  }

  syncFlyAngles() {
    this.rotation.setFromQuaternion(this.camera.quaternion, 'YXZ');
    this.yaw = this.rotation.y;
    this.pitch = this.rotation.x;
  }

  setMode(mode) {
    if (mode === this.mode) return;
    this.keys.clear();
    if (mode === 'fly') this.syncFlyAngles();
    else {
      this.distance = this.desiredDistance = this.camera.position.length();
      this.phi = this.desiredPhi = Math.acos(THREE.MathUtils.clamp(this.camera.position.y / this.distance, -1, 1));
      this.theta = this.desiredTheta = Math.atan2(this.camera.position.x, this.camera.position.z);
    }
    this.mode = mode;
  }

  preset(view) {
    this.setMode('orbit');
    this.desiredDistance = 34;
    this.desiredTheta = 0;
    this.desiredPhi = view === 'top' ? 0.08 : view === 'bottom' ? Math.PI - 0.08 : Math.PI / 2 - 0.13;
  }

  update(dt, autoOrbit, horizonRadius) {
    if (this.mode === 'orbit') {
      if (autoOrbit && !this.dragging) this.desiredTheta += dt * 0.065;
      if (this.keys.has('KeyA')) this.desiredTheta += dt * 0.7;
      if (this.keys.has('KeyD')) this.desiredTheta -= dt * 0.7;
      if (this.keys.has('KeyW')) this.desiredDistance *= Math.exp(-dt * 0.5);
      if (this.keys.has('KeyS')) this.desiredDistance *= Math.exp(dt * 0.5);
      this.desiredDistance = THREE.MathUtils.clamp(this.desiredDistance, horizonRadius * 1.08, 200);
      const smoothing = 1 - Math.exp(-dt * 14);
      this.theta = THREE.MathUtils.lerp(this.theta, this.desiredTheta, smoothing);
      this.phi = THREE.MathUtils.lerp(this.phi, this.desiredPhi, smoothing);
      this.distance = THREE.MathUtils.lerp(this.distance, this.desiredDistance, smoothing);
      this.camera.position.set(
        this.distance * Math.sin(this.phi) * Math.sin(this.theta),
        this.distance * Math.cos(this.phi),
        this.distance * Math.sin(this.phi) * Math.cos(this.theta),
      );
      this.camera.lookAt(this.target);
    } else {
      this.rotation.set(this.pitch, this.yaw, 0, 'YXZ');
      this.camera.quaternion.setFromEuler(this.rotation);
      this.forward.set(0, 0, -1).applyQuaternion(this.camera.quaternion);
      this.right.set(1, 0, 0).applyQuaternion(this.camera.quaternion);
      this.vector.set(0, 0, 0);
      if (this.keys.has('KeyW')) this.vector.add(this.forward);
      if (this.keys.has('KeyS')) this.vector.sub(this.forward);
      if (this.keys.has('KeyD')) this.vector.add(this.right);
      if (this.keys.has('KeyA')) this.vector.sub(this.right);
      if (this.keys.has('KeyE')) this.vector.y += 1;
      if (this.keys.has('KeyQ')) this.vector.y -= 1;
      const boost = this.keys.has('ShiftLeft') || this.keys.has('ShiftRight') ? 4 : 1;
      if (this.vector.lengthSq() > 0) this.camera.position.addScaledVector(this.vector.normalize(), dt * this.flySpeed * boost);
      // Keep the observer outside the coordinate singularity, with no opaque fake sphere.
      if (this.camera.position.length() < horizonRadius * 1.08) this.camera.position.setLength(horizonRadius * 1.08);
    }
    this.camera.updateMatrixWorld();
  }
}
