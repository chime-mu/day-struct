// Timeline hook — drag-to-schedule, move blocks, resize blocks
const Timeline = {
  mounted() {
    this.timeline = this.el;
    this.dayStart = parseInt(this.el.dataset.dayStart);
    this.dayEnd = parseInt(this.el.dataset.dayEnd);
    this.ppm = parseFloat(this.el.dataset.ppm);

    this.draggingBlock = null;
    this.resizingBlock = null;
    this.startY = 0;
    this.startMinute = 0;
    this.startDuration = 0;

    // Block dragging
    this.timeline.addEventListener("pointerdown", (e) => this.onPointerDown(e));
    this.timeline.addEventListener("pointermove", (e) => this.onPointerMove(e));
    this.timeline.addEventListener("pointerup", (e) => this.onPointerUp(e));
    this.timeline.addEventListener("pointercancel", (e) => this.onPointerUp(e));

    // Drag from sidebar
    this.timeline.addEventListener("dragover", (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = "copy";

      // Check if hovering over a time-block
      const blockEl = e.target.closest(".time-block");
      this.clearBlockDragover();
      if (blockEl) {
        blockEl.classList.add("time-block-dragover");
      } else {
        this.timeline.classList.add("timeline-dragover");
      }
    });

    this.timeline.addEventListener("dragleave", (e) => {
      if (!this.timeline.contains(e.relatedTarget)) {
        this.timeline.classList.remove("timeline-dragover");
        this.clearBlockDragover();
      }
    });

    this.timeline.addEventListener("drop", (e) => {
      e.preventDefault();
      this.timeline.classList.remove("timeline-dragover");
      this.clearBlockDragover();
      const taskId = e.dataTransfer.getData("text/plain");
      if (!taskId) return;

      // Check if dropped on an existing time block
      const blockEl = e.target.closest(".time-block");
      if (blockEl) {
        const blockId = blockEl.dataset.blockId;
        this.pushEvent("add_task_to_block", {
          block_id: blockId,
          task_id: taskId,
        });
        return;
      }

      const inner = this.timeline.querySelector(":scope > div");
      const rect = inner.getBoundingClientRect();
      const offsetY = e.clientY - rect.top + this.timeline.scrollTop;
      const minute = this.snapToGrid(this.dayStart + offsetY / this.ppm);

      this.pushEvent("schedule_task", { task_id: taskId, start_minute: minute });
    });

    // Setup sidebar drag sources
    this.setupSidebarDrag();
  },

  updated() {
    this.setupSidebarDrag();
  },

  clearBlockDragover() {
    this.timeline
      .querySelectorAll(".time-block-dragover")
      .forEach((el) => el.classList.remove("time-block-dragover"));
  },

  setupSidebarDrag() {
    document.querySelectorAll(".sidebar-task").forEach((el) => {
      el.addEventListener("dragstart", (e) => {
        e.dataTransfer.setData("text/plain", el.dataset.taskId);
        e.dataTransfer.effectAllowed = "copy";
        el.classList.add("opacity-50");
      });
      el.addEventListener("dragend", (e) => {
        el.classList.remove("opacity-50");
      });
    });
  },

  onPointerDown(e) {
    // Check for resize handle
    const resizeHandle = e.target.closest(".resize-handle");
    if (resizeHandle) {
      const block = resizeHandle.closest(".time-block");
      if (!block) return;
      this.resizingBlock = block;
      this.startY = e.clientY;
      this.startDuration = parseInt(block.dataset.durationMinutes);
      block.setPointerCapture(e.pointerId);
      e.preventDefault();
      return;
    }

    // Check for time-block drag
    const block = e.target.closest(".time-block");
    if (!block) return;

    // Don't drag if clicking buttons
    if (e.target.closest("button")) return;

    this.draggingBlock = block;
    this.startY = e.clientY;
    this.startMinute = parseInt(block.dataset.startMinute);
    block.setPointerCapture(e.pointerId);
    block.style.zIndex = "10";
    block.style.opacity = "0.8";
    e.preventDefault();
  },

  onPointerMove(e) {
    if (this.resizingBlock) {
      const dy = e.clientY - this.startY;
      const dMinutes = dy / this.ppm;
      const newDuration = this.snapToGrid(Math.max(15, this.startDuration + dMinutes));

      this.resizingBlock.style.height = `${newDuration * this.ppm}px`;
      this.resizingBlock._pendingDuration = newDuration;
      return;
    }

    if (!this.draggingBlock) return;

    const dy = e.clientY - this.startY;
    const dMinutes = dy / this.ppm;
    const newStart = this.snapToGrid(this.startMinute + dMinutes);
    const clamped = Math.max(this.dayStart, Math.min(this.dayEnd - 15, newStart));

    this.draggingBlock.style.top = `${(clamped - this.dayStart) * this.ppm}px`;
    this.draggingBlock._pendingStart = clamped;
  },

  onPointerUp(e) {
    if (this.resizingBlock) {
      const block = this.resizingBlock;
      const newDuration = block._pendingDuration;
      this.resizingBlock = null;

      if (newDuration && newDuration !== parseInt(block.dataset.durationMinutes)) {
        this.pushEvent("resize_block", {
          block_id: block.dataset.blockId,
          duration_minutes: newDuration,
        });
      }
      return;
    }

    if (!this.draggingBlock) return;

    const block = this.draggingBlock;
    block.style.zIndex = "";
    block.style.opacity = "";
    this.draggingBlock = null;

    const newStart = block._pendingStart;
    if (newStart != null && newStart !== parseInt(block.dataset.startMinute)) {
      this.pushEvent("move_block", {
        block_id: block.dataset.blockId,
        start_minute: newStart,
      });
    }
    block._pendingStart = null;
  },

  snapToGrid(minutes) {
    return Math.round(minutes / 15) * 15;
  },
};

export default Timeline;
