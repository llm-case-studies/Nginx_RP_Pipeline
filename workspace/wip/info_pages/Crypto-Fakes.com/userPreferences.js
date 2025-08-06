export function saveUserPreference(preference) {
    localStorage.setItem('animationPreference', preference);
    console.log(`User preference saved: ${preference}`);
}

export function getUserPreference() {
    const preference = localStorage.getItem('animationPreference') || null;
    console.log(`Retrieved user preference: ${preference}`);
    return preference;
}

// Ask the user for their animation preference using the floating div
// export function askUserPreference() {
//     const userPreference = getUserPreference();
//     if (userPreference) return; // Don't ask again if preference already exists

//     const promptDiv = document.getElementById('animation-prompt');
//     promptDiv.style.display = 'block'; // Show the floating div

//     // Handle "Allow All Animations" button
//     promptDiv.querySelector('.allow').addEventListener('click', () => {
//         saveUserPreference('all');
//         console.log("User allowed all animations.");
//         hidePrompt();
//     });

//     // Handle "Only Mild Animations" button
//     promptDiv.querySelector('.mild').addEventListener('click', () => {
//         saveUserPreference('mild');
//         console.log("User allowed only mild animations.");
//         hidePrompt();
//     });

//     // Handle "No Animations" button
//     promptDiv.querySelector('.disallow').addEventListener('click', () => {
//         saveUserPreference('none');
//         console.log("User disabled all animations.");
//         hidePrompt();
//     });

//     function hidePrompt() {
//         promptDiv.style.display = 'none'; // Hide the floating div
//     }
// }
export function askUserPreference() {
    const userPreference = getUserPreference();
    if (userPreference) return; // Don't ask again if preference already exists

    const promptDiv = document.getElementById('animation-prompt');
    promptDiv.style.display = 'block'; // Show the floating div
    promptDiv.style.opacity = '1'; // Fade in
    promptDiv.style.transform = 'scale(1)'; // Grow to full size

    // Add the animation
    promptDiv.style.animation = 'prompt-dance 1s ease-in-out 0.6s';

    // Handle "Allow All Animations" button
    promptDiv.querySelector('.allow').addEventListener('click', () => {
        saveUserPreference('all');
        console.log("User allowed all animations.");
        hidePrompt();
    });

    // Handle "Only Mild Animations" button
    promptDiv.querySelector('.mild').addEventListener('click', () => {
        saveUserPreference('mild');
        console.log("User allowed only mild animations.");
        hidePrompt();
    });

    // Handle "No Animations" button
    promptDiv.querySelector('.disallow').addEventListener('click', () => {
        saveUserPreference('none');
        console.log("User disabled all animations.");
        hidePrompt();
    });

    function hidePrompt() {
        promptDiv.style.animation = 'none'; // Remove animation
        promptDiv.style.opacity = '0'; // Fade out
        promptDiv.style.transform = 'scale(0)'; // Minimize
        setTimeout(() => {
            promptDiv.style.display = 'none'; // Hide after fade-out
        }, 500);
    }
}

export function reviewUserPreference() {
    const promptDiv = document.getElementById('animation-prompt');
    if (!promptDiv) {
        console.error("Preferences prompt not found!");
        return;
    }

    // Show the preferences div
    promptDiv.style.display = 'block';
    promptDiv.style.opacity = '1'; // Ensure it fades in
    promptDiv.style.transform = 'scale(1)'; // Animate to full size

    // Add the animation
    promptDiv.style.animation = 'prompt-dance 3s ease-in-out 0.6s';

    // Handle "Allow All Animations" button
    promptDiv.querySelector('.allow').addEventListener('click', () => {
        saveUserPreference('all');
        console.log("User allowed all animations.");
        hidePrompt();
    });

    // Handle "Only Mild Animations" button
    promptDiv.querySelector('.mild').addEventListener('click', () => {
        saveUserPreference('mild');
        console.log("User allowed only mild animations.");
        hidePrompt();
    });

    // Handle "No Animations" button
    promptDiv.querySelector('.disallow').addEventListener('click', () => {
        saveUserPreference('none');
        console.log("User disabled all animations.");
        hidePrompt();
    });

    function hidePrompt() {
        promptDiv.style.animation = 'none'; // Remove animation
        promptDiv.style.opacity = '0'; // Fade out
        promptDiv.style.transform = 'scale(0)'; // Minimize
        setTimeout(() => {
            promptDiv.style.display = 'none'; // Hide after fade-out
        }, 500);
    }
}
