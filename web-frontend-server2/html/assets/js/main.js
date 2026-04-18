document.addEventListener('DOMContentLoaded', function() {
  console.log('MyMiniCloud Web Server 2 loaded');
  const links = document.querySelectorAll('.services-grid a');
  links.forEach(l => l.addEventListener('mouseenter', () => l.style.transform = 'scale(1.03)'));
  links.forEach(l => l.addEventListener('mouseleave', () => l.style.transform = ''));
});
