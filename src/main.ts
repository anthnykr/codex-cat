import "./styles.css";

type Vector = {
  x: number;
  y: number;
};

type Bounds = {
  width: number;
  height: number;
};

type CatWalkerOptions = {
  node: HTMLElement;
  boundary: HTMLElement;
  size: Vector;
  speed: number;
};

class CatWalker {
  private animationFrame = 0;
  private bounds: Bounds = { width: 0, height: 0 };
  private lastTimestamp = performance.now();
  private position: Vector = { x: 40, y: 48 };
  private velocity: Vector;

  constructor(private readonly options: CatWalkerOptions) {
    this.velocity = this.normalize({ x: 1, y: 0.45 }, options.speed);
    this.measure();
    window.addEventListener("resize", this.handleResize);
    this.animationFrame = requestAnimationFrame(this.tick);
  }

  destroy(): void {
    window.removeEventListener("resize", this.handleResize);
    cancelAnimationFrame(this.animationFrame);
  }

  private readonly handleResize = (): void => {
    this.measure();
    this.position.x = Math.min(this.position.x, this.maxX);
    this.position.y = Math.min(this.position.y, this.maxY);
    this.render();
  };

  private readonly tick = (timestamp: number): void => {
    const deltaSeconds = Math.min(
      (timestamp - this.lastTimestamp) / 1000,
      0.05,
    );
    this.lastTimestamp = timestamp;

    this.position.x += this.velocity.x * deltaSeconds;
    this.position.y += this.velocity.y * deltaSeconds;
    this.resolveCollisions();
    this.render();

    this.animationFrame = requestAnimationFrame(this.tick);
  };

  private get maxX(): number {
    return Math.max(this.bounds.width - this.options.size.x, 0);
  }

  private get maxY(): number {
    return Math.max(this.bounds.height - this.options.size.y, 0);
  }

  private measure(): void {
    const rect = this.options.boundary.getBoundingClientRect();
    this.bounds = {
      width: rect.width,
      height: rect.height,
    };
  }

  private normalize(vector: Vector, speed: number): Vector {
    const length = Math.hypot(vector.x, vector.y);

    return {
      x: (vector.x / length) * speed,
      y: (vector.y / length) * speed,
    };
  }

  private render(): void {
    const direction = this.velocity.x >= 0 ? "right" : "left";

    this.options.node.dataset.direction = direction;
    this.options.node.style.transform = `translate3d(${this.position.x}px, ${this.position.y}px, 0)`;
  }

  private resolveCollisions(): void {
    if (this.position.x <= 0) {
      this.position.x = 0;
      this.velocity.x = Math.abs(this.velocity.x);
    } else if (this.position.x >= this.maxX) {
      this.position.x = this.maxX;
      this.velocity.x = -Math.abs(this.velocity.x);
    }

    if (this.position.y <= 0) {
      this.position.y = 0;
      this.velocity.y = Math.abs(this.velocity.y);
    } else if (this.position.y >= this.maxY) {
      this.position.y = this.maxY;
      this.velocity.y = -Math.abs(this.velocity.y);
    }
  }
}

const catNode = document.querySelector<HTMLElement>("#cat");
const boundaryNode = document.querySelector<HTMLElement>(".codex-surface");

if (!catNode || !boundaryNode) {
  throw new Error("Cat prototype could not find its required DOM nodes.");
}

new CatWalker({
  node: catNode,
  boundary: boundaryNode,
  size: { x: 56, y: 32 },
  speed: 118,
});
