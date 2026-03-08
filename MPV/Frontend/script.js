// frontend/script.js
let scene, camera, renderer, controls;
let uploadedFileName = null;
let animFrameId = null;

// Which arrow buttons are currently held down
const held = { ArrowLeft: false, ArrowRight: false, ArrowUp: false, ArrowDown: false };

const uploadInput    = document.getElementById('upload');
const uploadBtn      = document.getElementById('uploadBtn');
const processBtn     = document.getElementById('processBtn');
const sceneContainer = document.getElementById('sceneContainer');

/* ── Upload ──────────────────────────────────────────────────────────── */
uploadBtn.addEventListener('click', async () => {
  const file = uploadInput.files[0];
  if (!file) { alert("Select a file first!"); return; }

  const formData = new FormData();
  formData.append('file', file);

  uploadBtn.textContent = 'Uploading…';
  try {
    const res  = await fetch('/upload/', { method: 'POST', body: formData });
    const data = await res.json();
    uploadedFileName = data.filename;
    uploadBtn.textContent = '✓ Uploaded';
    processBtn.disabled = false;
  } catch (e) {
    alert("Upload failed: " + e.message);
    uploadBtn.textContent = 'Upload';
  }
});

/* ── Process ─────────────────────────────────────────────────────────── */
processBtn.addEventListener('click', () => {
  if (!uploadedFileName) { alert("Upload a video first!"); return; }
  initRoomTour(uploadedFileName);
});

/* ── Pan helper (moves camera target along a sphere) ─────────────────── */
const STEP = 0.045;

function pan(direction) {
  if (!controls) return;
  const sph = new THREE.Spherical().setFromVector3(
    controls.target.clone().sub(camera.position)
  );
  if (direction === 'ArrowLeft')  sph.theta += STEP;
  if (direction === 'ArrowRight') sph.theta -= STEP;
  if (direction === 'ArrowUp')    sph.phi   -= STEP;
  if (direction === 'ArrowDown')  sph.phi   += STEP;
  sph.phi = Math.max(0.05, Math.min(Math.PI - 0.05, sph.phi));
  controls.target.copy(new THREE.Vector3().setFromSpherical(sph));
  controls.update();
}

/* ── Keyboard arrow keys (still supported) ───────────────────────────── */
document.addEventListener('keydown', (e) => {
  if (e.key in held) { held[e.key] = true; e.preventDefault(); }
});
document.addEventListener('keyup', (e) => {
  if (e.key in held) held[e.key] = false;
});

/* ── On-screen D-pad ─────────────────────────────────────────────────── */
function buildArrowPad() {
  const pad = document.createElement('div');
  pad.style.cssText = `
    position: absolute;
    bottom: 20px;
    right: 20px;
    display: grid;
    grid-template-columns: repeat(3, 50px);
    grid-template-rows: repeat(3, 50px);
    gap: 5px;
    z-index: 20;
    user-select: none;
  `;

  const BASE_BG = 'rgba(255,255,255,0.15)';
  const HOLD_BG = 'rgba(255,255,255,0.40)';

  const BTN_BASE = `
    width:50px; height:50px;
    background:${BASE_BG};
    border:1px solid rgba(255,255,255,0.28);
    border-radius:9px;
    color:#fff;
    font-size:20px;
    cursor:pointer;
    display:flex; align-items:center; justify-content:center;
    backdrop-filter:blur(6px);
    -webkit-backdrop-filter:blur(6px);
    transition:background 0.1s, transform 0.08s;
    -webkit-tap-highlight-color:transparent;
    outline:none;
  `;

  const defs = [
    { dir: 'ArrowUp',    label: '▲', col: 2, row: 1 },
    { dir: 'ArrowLeft',  label: '◀', col: 1, row: 2 },
    { dir: 'ArrowDown',  label: '▼', col: 2, row: 3 },
    { dir: 'ArrowRight', label: '▶', col: 3, row: 2 },
  ];

  defs.forEach(({ dir, label, col, row }) => {
    const btn = document.createElement('button');
    btn.textContent = label;
    btn.style.cssText = BTN_BASE;
    btn.style.gridColumn = String(col);
    btn.style.gridRow    = String(row);

    const press   = () => { held[dir] = true;  btn.style.background = HOLD_BG; btn.style.transform = 'scale(0.88)'; };
    const release = () => { held[dir] = false; btn.style.background = BASE_BG; btn.style.transform = 'scale(1)'; };

    btn.addEventListener('mousedown',   press);
    btn.addEventListener('mouseup',     release);
    btn.addEventListener('mouseleave',  release);
    btn.addEventListener('touchstart',  (e) => { e.preventDefault(); press();   }, { passive: false });
    btn.addEventListener('touchend',    (e) => { e.preventDefault(); release(); }, { passive: false });
    btn.addEventListener('touchcancel', (e) => { e.preventDefault(); release(); }, { passive: false });

    pad.appendChild(btn);
  });

  sceneContainer.appendChild(pad);
}

/* ── Three.js scene ──────────────────────────────────────────────────── */
function initRoomTour(fileName) {
  if (animFrameId) cancelAnimationFrame(animFrameId);

  sceneContainer.style.display  = 'block';
  sceneContainer.style.position = 'relative';
  sceneContainer.innerHTML = '';

  const width  = sceneContainer.clientWidth;
  const height = sceneContainer.clientHeight;

  scene  = new THREE.Scene();
  camera = new THREE.PerspectiveCamera(75, width / height, 0.1, 1000);
  camera.position.set(0, 0, 0.001);

  renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setPixelRatio(window.devicePixelRatio);
  renderer.setSize(width, height);
  sceneContainer.appendChild(renderer.domElement);

  /* OrbitControls – DISABLED for mouse/touch drag; only arrow buttons work */
  controls = new THREE.OrbitControls(camera, renderer.domElement);
  controls.enableZoom    = false;
  controls.enablePan     = false;
  controls.enableRotate  = false;   // ← no mouse/touch drag rotation
  controls.autoRotate    = false;
  controls.target.set(0, 0, 0);
  controls.update();

  buildArrowPad();

  /* Resize */
  window.addEventListener('resize', () => {
    const w = sceneContainer.clientWidth;
    const h = sceneContainer.clientHeight;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
  });

  /* ── Video – loaded but PAUSED (used as a still-image texture) ────── */
  const video = document.createElement('video');
  video.src         = `/uploads/${fileName}`;
  video.crossOrigin = 'anonymous';
  video.loop        = false;
  video.muted       = true;
  video.playsInline = true;
  video.preload     = 'auto';
  video.style.display = 'none';
  document.body.appendChild(video);

  const label = document.createElement('div');
  label.textContent = 'Loading…';
  label.style.cssText =
    'position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);' +
    'color:#fff;font-size:1.1rem;pointer-events:none;z-index:5;';
  sceneContainer.appendChild(label);

  function buildSphere() {
    // Immediately pause – we only want a still panoramic frame
    video.pause();
    label.remove();

    const texture = new THREE.VideoTexture(video);
    texture.minFilter = THREE.LinearFilter;
    texture.magFilter = THREE.LinearFilter;

    const geometry = new THREE.SphereGeometry(500, 60, 40);
    geometry.scale(-1, 1, 1);

    const material = new THREE.MeshBasicMaterial({ map: texture });
    scene.add(new THREE.Mesh(geometry, material));

    animate();
  }

  /* Seek to the first frame then pause */
  video.addEventListener('loadeddata', () => {
    video.currentTime = 0;
  });

  /* Once seeked to frame 0, build the sphere */
  video.addEventListener('seeked', buildSphere, { once: true });

  video.load();
}

/* ── Animation loop ──────────────────────────────────────────────────── */
function animate() {
  animFrameId = requestAnimationFrame(animate);

  // Move camera only when an arrow is held
  for (const dir in held) {
    if (held[dir]) pan(dir);
  }

  controls.update();
  renderer.render(scene, camera);
}