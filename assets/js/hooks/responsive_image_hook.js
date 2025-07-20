export const ResponsiveImageHook = {
  mounted() {
    this.baseUrl = this.el.dataset.baseUrl;
    this.comicId = this.el.dataset.comicId;
    this.currentPage = this.el.dataset.currentPage;
    
    this.updateImageSrc();
    
    // Listen for orientation/resize changes
    this.resizeHandler = () => {
      this.updateImageSrc();
    };
    
    window.addEventListener('resize', this.resizeHandler);
    window.addEventListener('orientationchange', this.resizeHandler);
  },
  
  updated() {
    // When page changes, update the URLs and src
    this.currentPage = this.el.dataset.currentPage;
    this.updateImageSrc();
  },
  
  destroyed() {
    window.removeEventListener('resize', this.resizeHandler);
    window.removeEventListener('orientationchange', this.resizeHandler);
  },
  
  updateImageSrc() {
    const img = this.el.querySelector('img');
    if (!img) return;
    
    const isPortrait = window.innerHeight > window.innerWidth;
    
    if (isPortrait) {
      img.src = `/api/comics/${this.comicId}/page/${this.currentPage}?height=1200`;
      img.className = 'portrait-image block';
    } else {
      img.src = `/api/comics/${this.comicId}/page/${this.currentPage}`;
      img.className = 'landscape-image w-full h-auto object-contain';
    }
  }
};
