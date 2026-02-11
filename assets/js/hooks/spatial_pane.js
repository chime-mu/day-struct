// SpatialPane hook — free-form 2D drag using Pointer Events
const SpatialPane = {
  mounted() {
    this.pane = this.el;
    this.dragging = null;
    this.startX = 0;
    this.startY = 0;
    this.startLeft = 0;
    this.startTop = 0;

    this.pane.addEventListener("pointerdown", (e) => this.onPointerDown(e));
    this.pane.addEventListener("pointermove", (e) => this.onPointerMove(e));
    this.pane.addEventListener("pointerup", (e) => this.onPointerUp(e));
    this.pane.addEventListener("pointercancel", (e) => this.onPointerUp(e));

    this.positionCards();
  },

  updated() {
    this.positionCards();
  },

  positionCards() {
    const cards = this.pane.querySelectorAll(".task-card");
    cards.forEach((card) => {
      const x = parseFloat(card.dataset.x);
      const y = parseFloat(card.dataset.y);
      card.style.left = `${x * 100}%`;
      card.style.top = `${y * 100}%`;
      card.style.transform = "translate(-50%, -50%)";
    });
  },

  onPointerDown(e) {
    const card = e.target.closest(".task-card");
    if (!card || card.classList.contains("opacity-50")) return;

    // Don't start drag on click that will open editor
    this.dragStartTime = Date.now();
    this.dragMoved = false;

    this.dragging = card;
    this.startX = e.clientX;
    this.startY = e.clientY;

    const rect = this.pane.getBoundingClientRect();
    const cardRect = card.getBoundingClientRect();
    this.startLeft = cardRect.left + cardRect.width / 2 - rect.left;
    this.startTop = cardRect.top + cardRect.height / 2 - rect.top;

    card.setPointerCapture(e.pointerId);
    card.style.zIndex = "10";
    card.style.transition = "none";
    e.preventDefault();
  },

  onPointerMove(e) {
    if (!this.dragging) return;

    const dx = e.clientX - this.startX;
    const dy = e.clientY - this.startY;

    if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
      this.dragMoved = true;
    }

    const rect = this.pane.getBoundingClientRect();
    const newLeft = this.startLeft + dx;
    const newTop = this.startTop + dy;

    // Clamp within pane
    const x = Math.max(0, Math.min(1, newLeft / rect.width));
    const y = Math.max(0, Math.min(1, newTop / rect.height));

    this.dragging.style.left = `${x * 100}%`;
    this.dragging.style.top = `${y * 100}%`;
  },

  onPointerUp(e) {
    if (!this.dragging) return;

    const card = this.dragging;
    card.style.zIndex = "";
    card.style.transition = "";
    this.dragging = null;

    if (!this.dragMoved) return;

    const rect = this.pane.getBoundingClientRect();
    const cardRect = card.getBoundingClientRect();
    const centerX = cardRect.left + cardRect.width / 2 - rect.left;
    const centerY = cardRect.top + cardRect.height / 2 - rect.top;

    const x = Math.max(0.02, Math.min(0.98, centerX / rect.width));
    const y = Math.max(0.02, Math.min(0.98, centerY / rect.height));

    // Round to 4 decimal places
    const rx = Math.round(x * 10000) / 10000;
    const ry = Math.round(y * 10000) / 10000;

    card.dataset.x = rx;
    card.dataset.y = ry;

    this.pushEvent("move_task", { id: card.dataset.taskId, x: rx, y: ry });
  },
};

export default SpatialPane;
