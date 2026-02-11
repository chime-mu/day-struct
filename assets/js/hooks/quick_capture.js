// QuickCapture hook — Cmd+K global keyboard shortcut for inbox capture
const QuickCapture = {
  mounted() {
    this.modal = this.el;
    this.input = this.el.querySelector("input");
    this.isOpen = false;

    this.keyHandler = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault();
        this.toggle();
      }
      if (e.key === "Escape" && this.isOpen) {
        e.preventDefault();
        this.close();
      }
    };

    document.addEventListener("keydown", this.keyHandler);
  },

  destroyed() {
    document.removeEventListener("keydown", this.keyHandler);
  },

  toggle() {
    if (this.isOpen) {
      this.close();
    } else {
      this.open();
    }
  },

  open() {
    this.isOpen = true;
    this.modal.classList.remove("hidden");
    this.input && this.input.focus();
  },

  close() {
    this.isOpen = false;
    this.modal.classList.add("hidden");
    if (this.input) this.input.value = "";
  },
};

// AutoFocus hook — focus input on mount
const AutoFocus = {
  mounted() {
    this.el.focus();
  },
};

export { QuickCapture, AutoFocus };
