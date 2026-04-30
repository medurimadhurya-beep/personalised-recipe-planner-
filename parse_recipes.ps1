# Parse Kaggle CSV and generate data.js
$csvPath = "archive_data\food_recipes.csv"
$outputPath = "frontend\js\data.js"

$rows = Import-Csv -Path $csvPath -ErrorAction SilentlyContinue

$genericImages = @(
    "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=500&q=80",
    "https://images.unsplash.com/photo-1543339308-43e59d6b73a6?w=500&q=80",
    "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?w=500&q=80",
    "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=500&q=80",
    "https://images.unsplash.com/photo-1495521821757-a1efb6729352?w=500&q=80",
    "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=500&q=80",
    "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500&q=80",
    "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=500&q=80",
    "https://images.unsplash.com/photo-1588137378633-dea1336ce1e2?w=500&q=80",
    "https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=500&q=80"
)

function Map-Category($course, $tags, $diet) {
    $c = "$course $tags $diet".ToLower()
    if ($c -match "snack|breakfast|brunch|tea") { return "snacks" }
    if ($c -match "dinner") { return "dinner" }
    if ($c -match "lunch|main course|main dish") { return "lunch" }
    if ($c -match "protein|chicken|meat|fish|egg") { return "protein" }
    if ($c -match "pizza|burger|fast|sandwich|wrap") { return "fast-food" }
    return "regular"
}

function Sanitize-JS($str) {
    return ($str -replace '\\', '\\\\' -replace '"', '\"' -replace "`r", '' -replace "`n", ' ').Trim()
}

$allIngredients = [System.Collections.Generic.HashSet[string]]::new()
$recipes = [System.Collections.Generic.List[hashtable]]::new()
$id = 1
$imgIdx = 0

foreach ($row in $rows) {
    if ($recipes.Count -ge 100) { break }
    
    $name       = $row.recipe_title
    $ingStr     = $row.ingredients
    $instStr    = $row.instructions
    $course     = $row.course
    $cuisine    = $row.cuisine
    $prepTime   = $row.prep_time
    $cookTime   = $row.cook_time
    $tags       = $row.tags
    $diet       = $row.diet

    if (-not $name -or -not $ingStr -or -not $instStr) { continue }

    $ingredients = @()
    foreach ($part in ($ingStr -split '\|')) {
        $cl = ($part -replace '\([^)]*\)', '').Trim().ToLower()
        if ($cl -ne '') {
            $allIngredients.Add($cl) | Out-Null
            $ingredients += $cl
        }
    }
    $ingredients = $ingredients | Select-Object -First 10

    $steps = @()
    $sn = 1
    foreach ($s in ($instStr -split '\|')) {
        $desc = Sanitize-JS $s.Trim()
        if ($desc.Length -lt 10) { continue }
        $stepImg = $genericImages[($imgIdx + $sn) % $genericImages.Count]
        $steps += @{ title = "Step $sn"; desc = $desc; img = $stepImg }
        $sn++
        if ($sn -gt 8) { break }
    }
    if ($steps.Count -eq 0) { continue }

    $category = Map-Category $course $tags $diet
    $image    = $genericImages[$imgIdx % $genericImages.Count]
    $imgIdx++

    $time = "$prepTime + $cookTime".Trim(" +")
    if (-not $time) { $time = "30 mins" }

    $recipes.Add(@{
        id          = $id
        name        = (Sanitize-JS $name)
        category    = $category
        time        = (Sanitize-JS $time)
        city        = (Sanitize-JS $cuisine)
        ingredients = $ingredients
        image       = $image
        steps       = $steps
    })
    $id++
}

Write-Host "Parsed $($recipes.Count) recipes."

# Build JS
$sb = [System.Text.StringBuilder]::new()
$null = $sb.AppendLine("// Loaded from Kaggle Food Recipes Dataset")
$null = $sb.AppendLine("")
$null = $sb.AppendLine("const recipesDataset = [")

for ($i = 0; $i -lt $recipes.Count; $i++) {
    $r = $recipes[$i]
    $null = $sb.AppendLine("    {")
    $null = $sb.AppendLine("        id: $($r.id),")
    $null = $sb.AppendLine("        name: `"$($r.name)`",")
    $null = $sb.AppendLine("        category: `"$($r.category)`",")
    $null = $sb.AppendLine("        time: `"$($r.time)`",")
    $null = $sb.AppendLine("        city: `"$($r.city)`",")
    $ingrJson = ($r.ingredients | ForEach-Object { "`"$_`"" }) -join ", "
    $null = $sb.AppendLine("        ingredients: [$ingrJson],")
    $null = $sb.AppendLine("        image: `"$($r.image)`",")
    $null = $sb.AppendLine("        matchPercentage: 0,")
    $null = $sb.AppendLine("        steps: [")
    for ($j = 0; $j -lt $r.steps.Count; $j++) {
        $step = $r.steps[$j]
        $comma = if ($j -lt $r.steps.Count - 1) { "," } else { "" }
        $null = $sb.AppendLine("            { title: `"$($step.title)`", desc: `"$($step.desc)`", img: `"$($step.img)`" }$comma")
    }
    $null = $sb.AppendLine("        ]")
    if ($i -lt $recipes.Count - 1) { $null = $sb.AppendLine("    },") } else { $null = $sb.AppendLine("    }") }
}
$null = $sb.AppendLine("];")
$null = $sb.AppendLine("")

$ingrList = ($allIngredients | Select-Object -First 200 | ForEach-Object { "`"$_`"" }) -join ",`r`n    "
$null = $sb.AppendLine("const knownIngredients = [")
$null = $sb.AppendLine("    $ingrList")
$null = $sb.AppendLine("];")
$null = $sb.AppendLine("")

# Translations (avoid apostrophe issues by using here-string)
$translationsBlock = @"
// Dictionary for simple UI translations
const translations = {
    es: {
        "Home": "Inicio",
        "Scan Ingredients": "Escanear Ingredientes",
        "Recipes": "Recetas",
        "Popular": "Popular",
        "Made By Me": "Hecho Por Mi",
        "Recommended For You": "Recomendado Para Ti",
        "Upload Image": "Subir Imagen"
    },
    fr: {
        "Home": "Accueil",
        "Scan Ingredients": "Scanner les Ingredients",
        "Recipes": "Recettes",
        "Popular": "Populaire",
        "Made By Me": "Fait Par Moi",
        "Recommended For You": "Recommande Pour Vous",
        "Upload Image": "Telecharger image"
    }
};
"@
$null = $sb.Append($translationsBlock)

[System.IO.File]::WriteAllText((Resolve-Path $outputPath), $sb.ToString())
Write-Host "Done! data.js written successfully."
