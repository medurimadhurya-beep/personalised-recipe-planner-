const fs = require('fs');
const path = require('path');

const csvPath = path.join(__dirname, 'archive_data', 'food_recipes.csv');
const dataJsPath = path.join(__dirname, 'frontend', 'js', 'data.js');

const csvContent = fs.readFileSync(csvPath, 'utf8');
const lines = csvContent.split('\n');

const headers = lines[0].split(',');

const recipes = [];
let idCounter = 1;

// Helper to map Kaggle categories to our app's categories
function mapCategory(course, tags) {
    course = (course || "").toLowerCase();
    tags = (tags || "").toLowerCase();
    
    if (course.includes('snack') || tags.includes('snack')) return 'snacks';
    if (course.includes('dinner') || tags.includes('dinner')) return 'dinner';
    if (course.includes('lunch') || tags.includes('lunch')) return 'lunch';
    if (course.includes('breakfast')) return 'snacks'; // Map breakfast to snacks for now
    if (tags.includes('high protein') || tags.includes('chicken') || tags.includes('meat')) return 'protein';
    if (tags.includes('fast food') || tags.includes('pizza') || tags.includes('burger')) return 'fast-food';
    return 'regular';
}

const genericImages = [
    "https://images.unsplash.com/photo-1495521821757-a1efb6729352?w=500&q=80",
    "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?w=500&q=80",
    "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=500&q=80",
    "https://images.unsplash.com/photo-1543339308-43e59d6b73a6?w=500&q=80",
    "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=500&q=80"
];

const allIngredients = new Set();

for (let i = 1; i < lines.length; i++) {
    if (recipes.length >= 100) break; // Limit to 100 recipes to avoid huge file size

    const line = lines[i].trim();
    if (!line) continue;

    // Extremely basic CSV parsing (won't handle commas inside quotes perfectly, but enough for a mockup)
    // A better approach for a quick script: regex to split by commas outside quotes
    const matches = line.match(/(?:\"([^\"]*)\"|([^,]+))/g);
    if (!matches || matches.length < 15) continue;

    const row = matches.map(m => m.replace(/^"|"$/g, '').trim());
    
    const name = row[0];
    const cuisine = row[6] || "Global";
    const course = row[7];
    const prepTime = row[9] || "15 M";
    const ingredientsStr = row[11] || "";
    const instructionsStr = row[12] || "";
    const tags = row[14] || "";

    if (!name || !ingredientsStr || !instructionsStr) continue;

    const ingredients = ingredientsStr.split('|').map(i => {
        // Clean up ingredient names slightly (remove parenthesis info)
        let cleaned = i.replace(/\([^)]*\)/g, '').trim().toLowerCase();
        allIngredients.add(cleaned);
        return cleaned;
    }).filter(i => i);

    const stepsRaw = instructionsStr.split('|').map(s => s.trim()).filter(s => s.length > 5);
    const steps = stepsRaw.map((desc, idx) => ({
        title: `Step ${idx + 1}`,
        desc: desc,
        img: genericImages[idx % genericImages.length]
    }));

    if (steps.length === 0) continue;

    const category = mapCategory(course, tags);

    recipes.push({
        id: idCounter++,
        name: name,
        category: category,
        time: prepTime,
        city: cuisine,
        ingredients: ingredients,
        image: genericImages[idCounter % genericImages.length],
        matchPercentage: 0,
        steps: steps
    });
}

const knownIngredientsArray = Array.from(allIngredients);

const dataJsContent = `// Loaded from Kaggle Dataset

const recipesDataset = ${JSON.stringify(recipes, null, 4)};

const knownIngredients = ${JSON.stringify(knownIngredientsArray, null, 4)};

// Dictionary for simple UI translations
const translations = {
    es: {
        "Home": "Inicio",
        "Scan Ingredients": "Escanear Ingredientes",
        "Recipes": "Recetas",
        "Popular": "Popular",
        "Made By Me": "Hecho Por Mí",
        "Recommended For You": "Recomendado Para Ti",
        "Upload Image": "Subir Imagen"
    },
    fr: {
        "Home": "Accueil",
        "Scan Ingredients": "Scanner les Ingrédients",
        "Recipes": "Recettes",
        "Popular": "Populaire",
        "Made By Me": "Fait Par Moi",
        "Recommended For You": "Recommandé Pour Vous",
        "Upload Image": "Télécharger l'image"
    }
};
`;

fs.writeFileSync(dataJsPath, dataJsContent);
console.log('Successfully updated data.js with', recipes.length, 'recipes.');
