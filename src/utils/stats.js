export default class Stats {
    constructor() {
        this.fps = 0;
        this.frames = 0;
        this.lastTime = performance.now();
        this.panel = this.createPanel();
    }

    createPanel() {
        const div = document.createElement('div');
        div.style.position = 'fixed';
        div.style.top = '10px';
        div.style.left = '10px';
        div.style.padding = '8px';
        div.style.background = 'rgba(0, 0, 0, 0.7)';
        div.style.color = '#00ff00';
        div.style.fontFamily = 'monospace';
        div.style.fontSize = '12px';
        div.style.zIndex = '1000';
        div.style.pointerEvents = 'none';
        div.innerHTML = 'FPS: 0<br>MS: 0';
        document.body.appendChild(div);
        return div;
    }

    update() {
        this.frames++;
        const time = performance.now();
        
        if (time >= this.lastTime + 1000) {
            this.fps = Math.round((this.frames * 1000) / (time - this.lastTime));
            const ms = (time - this.lastTime) / this.frames;
            
            this.panel.innerHTML = `FPS: ${this.fps}<br>MS: ${ms.toFixed(2)}`;
            
            this.lastTime = time;
            this.frames = 0;
        }
    }
}