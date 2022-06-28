
### Prerequisites
- Es muss zuerst ein PAT (Personal Access Token) in Azure DevOps generiert werden, welcher dann in eine `.txt` Datei hinterlegt werden muss.

### Parameter

Alle Parameter für dieses Skript sind `Mandatory` , also müssen gesetzt sein damit das Skript laufen kann. Folgende Parameter müssen immer gesetzt sein:

- `-pj` oder `-project` : definiert das Projekt auf dem die Tickets erzeugt werden können. Dieser lässt sich auch in der URL ablesen bsplw. https://dev.azure.com/<ORG-NAME>/**<PROJECT>**

- `-pat`: definiert den Pfad zur PAT.txt Datei

Möchte man ein ganzes valides Verzeichniss mit Templates erzeugen so kann man folgenden Parameter nutzen:

`-td` oder `template-dir`:  definiert den Pfad zum Ordner in dem alle templates.json enthalten sind.

Möchte man hingegen nur einzelne Templates laden nutzt man folgende Parameter:

- `-rid` oder `-rootId`: definiert die Id des WorkItems unter dem die nachfolgenden `children` gesetzt werden sollen. Wird hier der String `"null"` übergeben, so werden den folgenden children kein parent zugeordnet.
- `-cs` oder `-children`: definiert ein Liste von template.json ( Info: Liste werden ìn PS mit Komma getrennt: `-cs a.json, b.json, c.json`

Es können **nicht** beide Varianten gesetzt werden. Im Default erwartet das Skript immer einen `-td` Eintrag. Sobald `-rid` gesetzt wurde **muss** auch `-cs` gesetzt. Es kann also nur folgende zwei Varianten geben:

`workitem-creator -pj ... -pat ... -td ...`

`workitem-creator -pj ... -pat ... -rid ... -cs ...`

### Json Einträge
Im folgenden ist erklärt welcher Eintrag was bedeutet.
Zuerst die Einträge welche die Template-Baum-Struktur aufbauen wenn der Parameter  `-td` oder `-template-dir` gesetzt ist:
| Eintrag | Bedeutung |
|--|--|
| root | Diese Json definiert die Wurzel der Template-Baum-Struktur. Nur relevant wenn `-td` oder `-template-dir` gesetzt sind. Bspl. "root" : true|
| pid | Diese Json definiert einen bereits existierenden Workitem als Parent für die Baum-Struktur. Darf nur in einer json definiert werden die auch `root` definiert. Nur relevant wenn `-td` oder `-template-dir` gesetzt sind. Bspl. "pid" : 11111|
| pjson | Diese Json ist kein direktes Child von der Root-Json sondern von einem anderen Json (also zb. Enkel etc.). Nur relevant wenn `-td` oder `-template-dir` gesetzt sind. Bspl. "pjson" : "a.json" |

Weiterführend werden nun die Einträge angegeben die für den Inhalt des Workitem wichtig sind:
|Einträge| Bedeutung |
|--|--|
| type | Definiert den Typen des Workitem. Bsplw. "type":"feature". **Muss** gesetzt sein.|
| title | Definiert den Titel des Workitem. Bsplw. "title":"testitem" **Muss** gesetzt sein. |
| description | Definiert die Beschreibung des Workitem. Bspl. "description":"lirum ipsum"(Optional) |
| tags | Definiert eine Liste von Tags für das Workitem. DevOps setzt folgendes Format vor: "tags":"Tag1; Tag2; Tag3". (Optional)|
| assignedTo | Definiert den User der das Workitem bearbeiten soll. DevOps möchte hier die volle Email-Adresse angegeben habe "assignedTo" : "abc@google.de". (Optional)|

### Valide Templates
#### -template-dir
Wenn man einen Orden von Templates laden will, werden vorher die jsons validiert. Hierbei werden hauptsächlich auf passende Einträge geachtet:

- Es dürfen keine Duplikate dabei sein.
	-  Hierbei wir nur der Dateiname kontrolliert.
- Root:
	- Es muss ( und darf nur ) genau eine .json existieren die `"root"` definiert.
	- Nur die root-json darf `"pid"` definieren
	- 	`"pjson"` darf nur in nicht-root json definiert sein
- Es müssen mind. `"title"` und `"type"` definiert sein.
- Workitem die nicht Root sind müssen `"pjson"` defineiren.
	- Es wird kontrolliert ob die Json im aktuellen Verzeichniss existiert.

### Template-Baum-Struktur Bspl.
Wenn der Paramet `-td` gesetzt ist werden die Workitems gemäß einer Baumstruktur erzeugt die wie folgt aussehen kann:

```
a.json (root no pid)
├── b.json
├── c.json
│   ├── d.json
|   ├── e.json
│   │   ├── f.json
│   ├── g.json
```
- a.json definierte hier keine pid und demnach kein parent als Workitem
- alle Kinder definierten ihren Vater als pjson. bsplw. in b.json ( "pjson" : "a.json")


```
workitem in devops with id = 11111
^
|
a.json (root mit pid = 11111)
├── b.json
├── c.json
│   ├── d.json
|   ├── e.json
│   │   ├── f.json
│   ├── g.json
```
- a.json wird dem Workitem mit der Id 11111 als Kind zugeordnet, alles ander bleibt gleich.

#### Single level upload
Wenn der Paramet `-rid` gesetzt ist werden die Workitems bei "null" auf der obersten Ebene eingefügt (so wie bei `-td` ohne `pid`). 
Wenn eine tatsächliche ID für `-rid` angegeben ist, so landen alle children unter dieser Id

... -rid null -cs a.json, b.json
```
a.json
b.json
```
- Es wurden einfach zwei Workitems auf der obersten Ebene erstellt.


... -rid 11111 -cs a.json, b.json
```
workitem in devops with id = 11111
^
|
a.json
b.json
```
