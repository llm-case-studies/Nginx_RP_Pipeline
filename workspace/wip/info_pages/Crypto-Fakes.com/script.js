import { startAnimation, stopAnimation, isAnimationRunning } from './animations.js';
import { askUserPreference, reviewUserPreference } from './userPreferences.js';

export function reportActivity(category, action, label, value, event_type = 'event', debug = false) {
  debug = true;
  console.log("reportActivity called:", {
    category: category,
    action: action,
    label: label,
    value: value,
    event_type: event_type,
    debug: debug
  });

  if (typeof gtag === 'function') {
    if (event_type === 'page_view') {
      gtag('event', 'page_view', {
        page_title: label.charAt(0).toUpperCase() + label.slice(1),
        page_location: window.location.origin + '#' + label
      });
    } else {
      const eventParams = {
        'event_category': category,
        'event_label': label,
        'value': value
      };
      if (debug) {
        eventParams.debug_mode = true;
      }
      gtag(event_type, action, eventParams);
    }
  } else {
    console.warn('gtag is not defined. Event not tracked:', category, action, label);
  }
}


document.getElementById('toggle-sidebar').addEventListener('click', function () {
  const sidebar = document.getElementById('sidebar');
  const content = document.getElementById('content');

  sidebar.classList.toggle('sidebar-collapsed'); 1
  content.classList.toggle('content-expanded');

  // Toggle aria-expanded attribute for accessibility
  const isExpanded = !sidebar.classList.contains('sidebar-collapsed');
  document.getElementById('toggle-sidebar').setAttribute('aria-expanded', isExpanded);

  // Track sidebar toggle
  reportActivity('sidebar', 'toggle', isExpanded ? 'Expand' : 'Collapse');
});

document.addEventListener('DOMContentLoaded', function () {
  const preferencesButton = document.getElementById('preferences-button');
  if (preferencesButton) {
    preferencesButton.addEventListener('click', () => {
      console.log("Preferences button clicked.");
      reviewUserPreference(); // Trigger the floating preferences div
      // Track preferences button click
      reportActivity('button', 'click', 'Preferences');
    });
  }
});

const sidebarLinks = document.querySelectorAll('.sidebar a');
const contentArea = document.getElementById('content').querySelector('.container');

// Function to load content 
function loadContent(contentFile) {
  fetch('content/' + contentFile)
    .then(response => response.text())
    .then(html => {
      contentArea.innerHTML = html;
    })
    .catch(error => {
      console.error('Error loading content:', error);
      contentArea.innerHTML = '<p>Error loading content.</p>';
    });
}

// Load the Home content on page load
document.addEventListener('DOMContentLoaded', function () {
  loadContent('home.html'); // Load home.html initially

  // *** The fix: Move the sidebarLinks.forEach loop inside the DOMContentLoaded event listener ***
  sidebarLinks.forEach(link => {
    link.addEventListener('click', (event) => {
      event.preventDefault(); // Prevent default link behavior

      const contentFile = link.getAttribute('href').substring(1) + '.html'; // Extract filename from href
      loadContent(contentFile);

      // Track sidebar link clicks
      const page = link.getAttribute('href').substring(1);
      reportActivity('navigation', 'click', page);
    });
  });
});


let inactivityTimer;
// Inactivity timings
const inactivityThreshold = 15000; // 15 seconds (in ms)

function resetTimer() {
  clearTimeout(inactivityTimer);
  console.log("User interaction detected. Resetting inactivity timer.");

  // Stop the animation on user interaction
  stopAnimation();

  // Start the inactivity timer again
  inactivityTimer = setTimeout(() => {
    console.log("Inactivity detected. Starting animation...");
    startAnimation(resetTimer); // Pass resetTimer as a callback
  }, inactivityThreshold);
}


document.addEventListener('DOMContentLoaded', function () {
  console.log("Page loaded. Checking animation preferences...");

  // Start the animation immediately on page load
  startAnimation(resetTimer);

  // Stop animation on the first interaction and reset timer
  document.addEventListener('mousemove', resetTimer);
  document.addEventListener('click', resetTimer);

  // Start the inactivity timer initially
  inactivityTimer = setTimeout(() => {
    console.log("Inactivity detected. Starting animation...");
    startAnimation(resetTimer);
  }, inactivityThreshold);
});

// Animation prompt button click tracking
document.querySelector('.allow').addEventListener('click', function () {
  reportActivity('animation_prompt', 'click', 'allow');
});

document.querySelector('.mild').addEventListener('click', function () {
  reportActivity('animation_prompt', 'click', 'mild');
});

document.querySelector('.disallow').addEventListener('click', function () {
  reportActivity('animation_prompt', 'click', 'disallow');
});