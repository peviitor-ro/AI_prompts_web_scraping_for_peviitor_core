Vreau să extragi toate joburile active de pe pagina asta și să-mi întorci DOAR lista de joburi în formatul Job Model din `peviitor_core` (fără alte explicații, fără text în plus).

Context:
- Website joburi (UI): https://www.todayworkforce.com/jobs
- Website companie: https://www.todayworkforce.com
- Sursa de date firme (România): https://targetare.ro (sau API-ul lor)
- Numele companiei România: „TODAY WORKFORCE SRL”

========================================
TASK 1 (INTERN) – LEARN COMPANY MODEL
========================================
Scop: să afli corect CIF-ul, denumirea legală și adresa firmei din România, ca să poți popula câmpurile `company` și `cif` din Job Model cu valori 100% corecte. Rezultatul Task 1 NU se afișează către utilizator, este DOAR context intern.

1. Caută compania pe targetare.ro după nume sau CUI și identifică pagina dedicată:
   - ex.: https://targetare.ro/46225958/today-workforce-srl

2. Din pagina targetare.ro:
   - Ia exact „Codul unic de înregistrare (CUI)” (fără prefix RO).
   - Ia denumirea legală exactă a firmei (cu diacritice dacă există).
   - Ia descrierea sediului social (localitatea + adresă completă), cu diacritice.

3. Din aceste date, construiește intern (FĂRĂ să afișezi) un obiect Company Model de forma:

   JSON_START
   {
     "id": "<CIF>",
     "company": "<DENUMIRE LEGALĂ CU DIACRITICE>",
     "status": "activ|suspendat|inactiv|radiat",
     "location": "<Adresa/localitatea cu diacritice>",
     "website": "https://www.todayworkforce.com",
     "career": "https://www.todayworkforce.com/jobs"
   }
   JSON_END

   Reguli pentru status:
   - "functioneaza", "în funcțiune", "active" → "activ"
   - "suspendata", "suspendat" → "suspendat"
   - "radiata", "radiat", "dizolvata", "lichidata" → "radiat"
   - orice alt status neclar, dar firma nu este radiată → "inactiv"
   - Dacă nu găsești explicit un status, dar firma apare ca activă (date financiare recente, fără mențiuni de radiere), setează `status = "activ"`.
   - Dacă `status ≠ "activ"`, oprești TOT (nu mai extragi joburi).

4. FOARTE IMPORTANT:
   - Păstrezi intern:
     - `company` = denumirea legală exactă
     - `cif` = CIF/CUI exact (toate cifrele, fără RO)
   - Aceste două valori le vei folosi la popularea câmpurilor `company` și `cif` din fiecare job.

5. NU AFIȘA obiectul Company Model în răspunsul final. Task 1 este doar un pas de „învățare”/setare context pentru tine ca AI.

========================================
TASK 2 – SCRAPE JOBURI DIN https://www.todayworkforce.com/jobs
========================================
Dacă în Task 1 ai obținut `status = "activ"`, treci la extragerea joburilor din pagina de mai sus. OUTPUT-ul FINAL pentru acest prompt TREBUIE să fie DOAR ARRAY-UL JSON de joburi, în format Job Model `peviitor_core`, conform cerințelor de mai jos.

1. Încărcare și navigare:
   - Deschizi pagina https://www.todayworkforce.com/jobs.
   - Dacă există paginare / butoane „Next”, „Load more” sau similar, navighezi prin toate paginile astfel încât să acoperi TOATE joburile listate.
   - Ignori linkuri externe către alte platforme (ejobs, LinkedIn etc.), folosești doar conținutul direct de pe todayworkforce.com.

2. Identifică blocurile de job:
   - Găsești containerul/lista în care sunt afișate joburile (carduri, rânduri de tabel sau listă).
   - Pentru fiecare job activ (vizibil în listă) identifici:
     - titlul jobului
     - linkul către pagina de detaliu (dacă există)
     - locația / orașul
     - eventuale taguri (departament, tip job, nivel, industrie)
     - orice informație de tip remote/hybrid/on-site
     - data publicării / actualizării (dacă apare în listă sau în pagina de detaliu).

3. Pentru fiecare job activ, construiește un obiect JSON cu schema:

   - url (string, required)
     - Dacă există pagină de detaliu pentru job:
       - folosești URL-ul complet al paginii de detaliu.
       - Dacă linkul este relativ, îl transformi în absolut folosind domeniul https://www.todayworkforce.com.
     - Dacă jobul este afișat doar în listă, fără pagină dedicată:
       - folosești `https://www.todayworkforce.com/jobs` (optional cu ancora sau query dacă există).

   - title (string, required)
     - Titlul postului (exact cum apare în UI, dar fără HTML), trimmat, max 200 caractere, cu diacritice acceptate.

   - company (string, required)
     - Valoare fixă luată din Company Model intern (Task 1).
     - Pentru această firmă din România: denumirea legală exactă din targetare.ro (ex.: "TODAY WORKFORCE SRL").

   - cif (string, required)
     - Valoare fixă luată din Company Model intern (Task 1).
     - Pentru această firmă: CUI-ul/codul fiscal exact din targetare.ro (fără prefix RO).

   - location (string, optional)
     - Textul localității/localităților menționate pentru job (oraș +, eventual, țara).
     - Normalizează orașele românești:
       - "Bucuresti" → "București"
       - "Iasi" → "Iași"
       - "Pitesti" → "Pitești"
       - "Constanta" → "Constanța"
       - "Popesti Leordeni" → "Popești-Leordeni"
     - Dacă sunt mai multe locații, păstrează-le separate prin virgulă.
     - Dacă nu se menționează explicit orașul, poți omite câmpul `location`.

   - tags (array, optional)
     - Nu include câmpul dacă nu există taguri/keyworduri clare.
     - Dacă poți deriva taguri din titlu sau din elemente UI (de ex. domeniu, industrie, tip job, departament, nivel, limbă):
       - lowercase
       - fără diacritice
       - max 20 de valori
       - tip slug (doar litere, cifre, cratime), ex.:
         ["logistica","productie","muncitor-necalificat","cluj-napoca","full-time"]

   - workmode (string, optional)
     - Dacă apare clar „remote”, „work from home”, „hybrid”:
       - setezi "remote" sau "hybrid" în funcție de text.
     - Dacă textul sugerează clar prezență fizică (de ex. „on-site”, „lucru la sediul clientului/fabricii” etc.) sau nu se specifică:
       - setezi "on-site".

   - date (date, optional)
     - Dacă există o dată clară a publicării/actualizării jobului (în listă sau în pagina de detaliu):
       - Parsezi data (indiferent dacă este în română sau engleză) și o convertești în ISO8601 UTC cu ora 00:00:00Z.
       - Exemple:
         - „Publicat la: 16 ianuarie 2026” → "2026-01-16T00:00:00Z"
         - „Updated: 05 March 2025” → "2025-03-05T00:00:00Z"
       - Mapezi corect lunile românești (ianuarie, februarie, martie, aprilie, mai, iunie, iulie, august, septembrie, octombrie, noiembrie, decembrie).
     - Dacă nu există dată, nu include câmpul `date`.

   - status (string, optional)
     - Întotdeauna "scraped".

   - vdate (date, optional)
     - NU include acest câmp.

   - expirationdate (date, optional)
     - Dacă nu există o dată de expirare explicită:
       - dacă ai `date`:
         - expirationdate = date + 30 zile.
         - Format: ISO8601 UTC, ora 00:00:00Z.
       - dacă nu ai `date`:
         - NU include `expirationdate`.
     - Dacă există o dată de expirare în text/structură, o convertești în același format ISO8601 UTC.

   - salary (string, optional)
     - Include acest câmp DOAR dacă există informație clară despre salariu/interval salarial în text.
     - Păstrează textul lizibil (ex.: „4000–4500 lei net”, „4500 RON brut + bonusuri”).
     - Dacă nu există detalii clare de salariu, nu include câmpul `salary`.

----------------
REGULI DE OUTPUT
----------------
- NU întoarce NICIUN câmp cu valoare null sau array gol:
  - fără `"tags": []`
  - fără `"salary": null`
- Respectă EXACT numele câmpurilor și tipurile:
  - `url`, `title`, `company`, `cif`, `location`, `tags`, `workmode`, `date`, `status`, `expirationdate`, `salary`
- OUTPUT FINAL (ce îmi trimiți mie ca utilizator) = STRICT un ARRAY JSON:

  JSON_START
  [
    { ... },
    { ... },
    ...
  ]
  JSON_END

- Fără obiect root, fără Company Model afișat, fără explicații / comentarii în afara JSON-ului.
- În răspunsul tău către mine, pune acest ARRAY într-un bloc Markdown de tip ```json, astfel încât să pot face copy-paste direct în Solr.

IMPORTANT:
- Task 1 îl folosești DOAR pentru a-ți seta intern `company` și `cif` (și eventual pentru validări).
- Eu, ca utilizator, vreau să văd DOAR rezultatul Task 2: lista de joburi active în format Job Model `peviitor_core`, cu câmpurile `company` și `cif` completate corect pe baza datelor reale din targetare.ro.
