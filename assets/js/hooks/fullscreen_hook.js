import screenfull from 'screenfull';

export const FullscreenHook = {
  mounted() {
    this.targetElement = this.el.querySelector('[data-fullscreen-target]') || this.el;
    
    // Listen for fullscreen changes from browser
    if (screenfull.isEnabled) {
      this.changeHandler = () => {
        this.pushEvent('fullscreen_changed', {
          isFullscreen: screenfull.isFullscreen
        });
      };
      
      screenfull.on('change', this.changeHandler);
    }
    
    // Handle toggle events from LiveView
    this.handleEvent('toggle_fullscreen', () => {
      if (screenfull.isEnabled) {
        if (screenfull.isFullscreen) {
          screenfull.exit();
        } else {
          screenfull.request(this.targetElement);
        }
      }
    });
    
    // Handle direct fullscreen requests
    this.handleEvent('enter_fullscreen', () => {
      if (screenfull.isEnabled && !screenfull.isFullscreen) {
        screenfull.request(this.targetElement);
      }
    });
    
    this.handleEvent('exit_fullscreen', () => {
      if (screenfull.isEnabled && screenfull.isFullscreen) {
        screenfull.exit();
      }
    });
  },
  
  destroyed() {
    if (screenfull.isEnabled && this.changeHandler) {
      screenfull.off('change', this.changeHandler);
    }
  }
};
