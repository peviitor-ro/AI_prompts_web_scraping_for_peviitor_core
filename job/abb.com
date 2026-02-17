Textul de mai jos este exact ca primul tău prompt, doar că am înlocuit firma BIA cu ABB ASEA BROWN BOVERI SRL și site-urile aferente:

Vreau să rezolvi două taskuri în acest prompt, dar ca OUTPUT pentru mine să dai DOAR lista de joburi (Task 2). Task 1 îl rulezi intern, ca AI care își setează corect contextul despre companie (CIF, denumire, adresă), fără să-mi afișezi obiectul Company.

Context:

Website joburi: https://careers.abb

Website companie: https://new.abb.com/ro

Sursa de date firme: https://targetare.ro

Numele companiei afișat pe site-ul de joburi: "ABB ASEA BROWN BOVERI SRL"

========================================
TASK 1 (INTERN) – LEARN COMPANY MODEL
Scop: să afli corect CIF-ul, denumirea legală și adresa firmei, ca să poți popula câmpurile company și cif din Job Model cu valori 100% corecte. Rezultatul Task 1 NU se afișează către utilizator, este DOAR context intern.

Caută compania pe targetare.ro după nume sau CUI și identifică pagina dedicată:

ex.: https://targetare.ro/41422720/abb-asea-brown-boveri-srl

Din pagina targetare.ro:

Ia exact „Codul unic de înregistrare (CUI)” (8 cifre, fără prefix RO).

Ia denumirea legală exactă a firmei (cu diacritice dacă există).

Ia descrierea sediului social (localitatea + adresă completă), cu diacritice.

Din aceste date, construiește intern (FĂRĂ să afișezi) un obiect Company Model de forma:

{
"id": "<CIF_8_cifre>",
"company": "<DENUMIRE LEGALĂ CU DIACRITICE>",
"status": "activ|suspendat|inactiv|radiat",
"location": "<Adresa/localitatea cu diacritice>",
"website": "https://new.abb.com/ro",
"career": "https://careers.abb"
}

Reguli pentru status:

Mapează statusul din Registrul Comerțului / targetare.ro astfel:

"functioneaza", "în funcțiune", "active" → "activ"

"suspendata", "suspendat" → "suspendat"

"radiata", "radiat", "dizolvata", "lichidata" → "radiat"

orice alt status neclar, dar firma nu este radiată → "inactiv"

Dacă nu găsești explicit un status, dar firma apare ca activă (date financiare recente, fără mențiuni de radiere), setează status = "activ".

Dacă status ≠ "activ", oprești TOT (nu mai extragi joburi).

FOARTE IMPORTANT:

Păstrezi intern:

company = denumirea legală exactă

cif = CIF/CUI exact (8 cifre)

Aceste două valori le vei folosi la popularea câmpurilor company și cif din fiecare job.

NU AFIȘA obiectul Company Model în răspunsul final. Task 1 este doar un pas de „învățare”/setare context pentru tine ca AI.

========================================
TASK 2 – OUTPUT = LISTA DE JOBURI (Solr)
Dacă în Task 1 ai obținut status = "activ", treci la extragerea joburilor. OUTPUT-ul FINAL pentru acest prompt TREBUIE să fie DOAR ARRAY-UL JSON de joburi, în format Solr, conform cerințelor de mai jos.

Deschide și parcurge paginile:

https://careers.abb/global/en/search-results

https://careers.abb/global/en/search-results?pg={pagina} – iterează toate paginile existente din paginare.

Selectează DOAR joburile ACTIVE:

Include DOAR anunțurile care au dată de publicare vizibilă.

Ignoră COMPLET anunțurile marcate ca „no longer accepting applications”, „position closed” sau echivalent.

Pentru fiecare job activ, construiește un obiect JSON cu schema:

url (string, required)

URL-ul complet al paginii de detaliu a jobului (atributul href din titlul H3/H4/H5).

title (string, required)

Textul titlului jobului din link (ex.: „Commissioning Engineer Distribution Systems”),
fără HTML, trimmat, max 200 caractere, cu diacritice acceptate.

company (string, required)

Valoare fixă luată din Company Model intern (Task 1).

Pentru ABB: "ABB ASEA BROWN BOVERI SRL" (exact denumirea legală).

cif (string, required)

Valoare fixă luată din Company Model intern (Task 1).

Pentru ABB: "41422720" (8 cifre, fără RO).

location (string, optional)

Textul localității/localităților afișate în cardul jobului (ex.: „Bucharest, București, Romania”).

Dacă există multiple locații, păstrează formatul cu virgulă între ele.

tags (array, optional)

Nu include câmpul dacă nu există taguri în pagină.

Dacă există taguri:

lowercase

fără diacritice

max 20 de valori

tip slug (doar litere, cifre, cratime), ex.:
["finance","business-partner","energy","budgeting"]

workmode (string, optional)

Dacă nu apare explicit remote/hybrid pentru job:

setează "on-site".

Dacă apare clar „remote” sau „hybrid”, poți folosi "remote" sau "hybrid".

date (date, optional)

Data publicării jobului, dacă este vizibilă pe pagină.

Convertește în ISO8601 UTC cu ora 00:00:00Z.

status (string, optional)

Întotdeauna "scraped".

vdate (date, optional)

NU include acest câmp.

expirationdate (date, optional)

Dacă în HTML nu există dată de expirare:

expirationdate = date + 30 zile, dacă există date.

Format: ISO8601 UTC, ora 00:00:00Z.

salary (string, optional)

NU include acest câmp pentru această firmă, indiferent ce apare în text.

REGULI DE OUTPUT
NU întoarce NICIUN câmp cu valoare null sau array gol:

fără "tags": []

fără "salary": null

Respectă EXACT numele câmpurilor și tipurile:

url, title, company, cif, location, tags, workmode, date, status, expirationdate

OUTPUT FINAL (ce îmi trimiți mie ca utilizator) = STRICT un ARRAY JSON:
[
{ ... },
{ ... },
...
]

Fără obiect root, fără Company Model afișat, fără explicații / comentarii în afara JSON-ului.

Formatează ARRAY-ul într-un bloc Markdown de tip ```json, astfel încât să pot face copy-paste direct în Solr.

IMPORTANT:

Task 1 îl folosești DOAR pentru a-ți seta intern company și cif (și eventual pentru validări).

Eu, ca utilizator, vreau să văd DOAR rezultatul Task 2: lista de joburi active în format Solr, cu câmpurile company și cif completate corect pe baza datelor reale din targetare.ro pentru ABB ASEA BROWN BOVERI SRL.
