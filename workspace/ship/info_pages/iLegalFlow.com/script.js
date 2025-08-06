document.getElementById('toggle-sidebar').addEventListener('click', function() {
    const sidebar = document.getElementById('sidebar');
    const content = document.getElementById('content');

    sidebar.classList.toggle('sidebar-collapsed');
    content.classList.toggle('content-expanded');

    // Toggle aria-expanded attribute for accessibility
    const isExpanded = !sidebar.classList.contains('sidebar-collapsed');
    document.getElementById('toggle-sidebar').setAttribute('aria-expanded', isExpanded);
});

const sidebarLinks = document.querySelectorAll('.sidebar a');
const contentArea = document.getElementById('content').querySelector('.container');

sidebarLinks.forEach(link => {
  link.addEventListener('click', (event) => {
    event.preventDefault(); // Prevent default link behavior

    const contentFile = link.getAttribute('href').substring(1) + '.html'; // Extract filename from href

    fetch('content/' + contentFile)
      .then(response => response.text())
      .then(html => {
        contentArea.innerHTML = html; // Update content area with fetched HTML
      })
      .catch(error => {
        console.error('Error loading content:', error);
        contentArea.innerHTML = '<p>Error loading content.</p>';
      });
  });
});