// // animations.js


// export let isAnimationRunning = false;


// // Persistent named function for animationend
// function handleAnimationEnd(event, resetTimerCallback) {
//     console.log("Animation finished (event triggered).");
//     isAnimationRunning = false;
//     event.target.removeEventListener('animationend', onAnimationEnd); // Remove listener after use
//     if (resetTimerCallback) {
//         resetTimerCallback(); // Reset inactivity timer
//     }
// }

// // Wrapper function for adding the event listener
// function onAnimationEnd(event) {
//     handleAnimationEnd(event, resetTimerCallback); // Delegate to handleAnimationEnd
// }

// let resetTimerCallback; // Store resetTimer for use across instances


// export function startAnimation(resetTimerCallback) {
//     const navbar = document.getElementById('sidebar');
//     if (!navbar) {
//         console.error("Sidebar element not found.");
//         return;
//     }

//     // Check if animations are allowed
//     const userPreference = localStorage.getItem('animationPreference');
//     if (userPreference === 'none' || userPreference === 'mild') {
//         console.log("Animations disabled by user preference.");
//         return; // Exit if animations are not allowed
//     }

//     if (!isAnimationRunning) {
//         const animationName = getRandomAnimation();

//         // Reset animation to force re-trigger
//         navbar.style.animation = 'none';
//         void navbar.offsetWidth; // Trigger reflow
//         navbar.style.animation = `${animationName} 5s linear`;
//         console.log("Animation started.");
//         isAnimationRunning = true;

//         // Attach a single-use animationend listener
//         navbar.addEventListener(
//             'animationend',
//             function handleAnimationEnd() {
//                 console.log("Animation finished (event triggered).");
//                 isAnimationRunning = false;

//                 // Ask user for animation preferences after the first animation
//                 if (!userPreference) {
//                     askUserPreference();
//                 }

//                 // Ensure timer is reset
//                 if (resetTimerCallback) {
//                     resetTimerCallback();
//                 }
//             },
//             { once: true } // Ensure listener runs only once per animation
//         );
//     }
// }


// export function stopAnimation() {
//     const navbar = document.getElementById('sidebar');
//     if (!navbar) {
//         console.error("Sidebar element not found.");
//         return;
//     }

//     navbar.style.animation = 'none'; // Stop the animation immediately
//     console.log("Animation stopped.");
//     isAnimationRunning = false; // Reset the flag
// }

// function askUserPreference() {
//     // Ask the user for animation preference
//     const userChoice = confirm(
//         "Do you want to allow animations?\n" +
//         "Click OK for 'Yes', Cancel for 'No'."
//     );

//     // Save user preference in localStorage
//     if (userChoice) {
//         localStorage.setItem('animationPreference', 'all');
//         console.log("User allowed animations.");
//     } else {
//         const mildChoice = confirm(
//             "Would you like mild animations only?\n" +
//             "Click OK for 'Yes', Cancel for 'No animations at all'."
//         );

//         if (mildChoice) {
//             localStorage.setItem('animationPreference', 'mild');
//             console.log("User allowed mild animations.");
//         } else {
//             localStorage.setItem('animationPreference', 'none');
//             console.log("User disabled all animations.");
//         }
//     }
// }


// export function getAnimationNames() {
//     const animationNames = [];
//     for (const styleSheet of document.styleSheets) {
//       for (const rule of styleSheet.cssRules) {
//         if (rule.constructor.name === 'CSSKeyframesRule') {
//           animationNames.push(rule.name);
//         }
//       }
//     }
//     return animationNames;
// }
  
//   export function getRandomAnimation(preference) {
//     // const allAnimations = getAnimationNames();
  
//     // const filteredAnimations = allAnimations.filter(animationName => 
//     //   animationName.includes(preference) 
//     // );
  
//     // const randomIndex = Math.floor(Math.random() * filteredAnimations.length);
//     return "navbar-dance"; // Return the hardcoded animation name for now
//     // return filteredAnimations[randomIndex] || 'none'; 
//   }
  
//   // ... (other animation-related functions) ...
  
//   let animationStartTime = Date.now(); // Initialize animationStartTime here

// animations.js

import { getUserPreference, askUserPreference } from './userPreferences.js';

export let isAnimationRunning = false;

// Persistent named function for animationend
function handleAnimationEnd(event, resetTimerCallback) {
    console.log("Animation finished (event triggered).");
    isAnimationRunning = false;
    event.target.removeEventListener('animationend', onAnimationEnd); // Remove listener after use
    if (resetTimerCallback) {
        resetTimerCallback(); // Reset inactivity timer
    }
}

// Wrapper function for adding the event listener
function onAnimationEnd(event) {
    handleAnimationEnd(event, resetTimerCallback); // Delegate to handleAnimationEnd
}

let resetTimerCallback; // Store resetTimer for use across instances

export function startAnimation(resetTimerCallback) {
    const navbar = document.getElementById('sidebar');
    if (!navbar) {
        console.error("Sidebar element not found.");
        return;
    }

    // Check if animations are allowed
    const userPreference = getUserPreference();
    if (userPreference === 'none' || userPreference === 'mild') {
        console.log("Animations disabled by user preference.");
        return; // Exit if animations are not allowed
    }

    if (!isAnimationRunning) {
        const animationName = getRandomAnimation();

        // Reset animation to force re-trigger
        navbar.style.animation = 'none';
        void navbar.offsetWidth; // Trigger reflow
        navbar.style.animation = `${animationName} 5s linear`;
        console.log("Animation started.");
        isAnimationRunning = true;

        // Attach a single-use animationend listener
        navbar.addEventListener(
            'animationend',
            function handleAnimationEnd() {
                console.log("Animation finished (event triggered).");
                isAnimationRunning = false;

                // Ask user for animation preferences after the first animation
                if (!userPreference) {
                    askUserPreference();
                }

                // Ensure timer is reset
                if (resetTimerCallback) {
                    resetTimerCallback();
                }
            },
            { once: true } // Ensure listener runs only once per animation
        );
    }
}

export function stopAnimation() {
    const navbar = document.getElementById('sidebar');
    if (!navbar) {
        console.error("Sidebar element not found.");
        return;
    }

    navbar.style.animation = 'none'; // Stop the animation immediately
    console.log("Animation stopped.");
    isAnimationRunning = false; // Reset the flag
}

export function getAnimationNames() {
    const animationNames = [];
    for (const styleSheet of document.styleSheets) {
        for (const rule of styleSheet.cssRules) {
            if (rule.constructor.name === 'CSSKeyframesRule') {
                animationNames.push(rule.name);
            }
        }
    }
    return animationNames;
}

export function getRandomAnimation(preference) {
    // const allAnimations = getAnimationNames();
  
    // const filteredAnimations = allAnimations.filter(animationName => 
    //   animationName.includes(preference) 
    // );
  
    // const randomIndex = Math.floor(Math.random() * filteredAnimations.length);
    return "navbar-dance"; // Return the hardcoded animation name for now
    // return filteredAnimations[randomIndex] || 'none'; 
}

let animationStartTime = Date.now(); // Initialize animationStartTime here
