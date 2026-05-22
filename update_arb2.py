import json
import glob

files = glob.glob('lib/l10n/app_*.arb')
translations = {
    'pl': {
        'searchLocationPlaceholder': 'Szukaj miejscowości lub adresu...',
        'searchNoResults': 'Brak wyników'
    },
    'en': {
        'searchLocationPlaceholder': 'Search for a city or address...',
        'searchNoResults': 'No results found'
    },
    'es': {
        'searchLocationPlaceholder': 'Buscar una ciudad o dirección...',
        'searchNoResults': 'No se encontraron resultados'
    },
    'de': {
        'searchLocationPlaceholder': 'Suchen Sie nach einer Stadt oder Adresse...',
        'searchNoResults': 'Keine Ergebnisse gefunden'
    },
    'fr': {
        'searchLocationPlaceholder': 'Rechercher une ville ou une adresse...',
        'searchNoResults': 'Aucun résultat trouvé'
    },
    'it': {
        'searchLocationPlaceholder': 'Cerca una città o un indirizzo...',
        'searchNoResults': 'Nessun risultato trovato'
    }
}

for f in files:
    lang = f.split('_')[1].split('.')[0]
    with open(f, 'r', encoding='utf-8') as file:
        data = json.load(file)
    
    updates = translations.get(lang, translations['en'])
    for k, v in updates.items():
        if k not in data:
            data[k] = v
            
    with open(f, 'w', encoding='utf-8') as file:
        json.dump(data, file, ensure_ascii=False, indent=2)
