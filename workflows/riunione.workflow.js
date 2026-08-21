export const meta = {
  name: 'azienda-riunione',
  description: 'Dibattito aziendale sequenziale: N speaker in ruolo, R round, ognuno legge il transcript finora; chiude con un verbale del moderatore.',
  phases: [
    { title: 'Dibattito', detail: 'round sequenziali, uno speaker per volta' },
    { title: 'Verbale', detail: 'moderatore sintetizza il transcript' },
  ],
}

// args = {
//   topic: string,
//   rounds?: [{ title, instruction }]   // default 3 round sotto
//   speakers: [{ role, agentType?, persona?, model? }]  // ordine = ordine di parola
//   lang?: string                        // lingua del dibattito (default: dal topic)
//   moderatorModel?: string              // default opus
// }

const topic = args?.topic
const speakers = args?.speakers || []
if (!topic) throw new Error('args.topic mancante')
if (speakers.length < 2) throw new Error('servono almeno 2 speaker (una riunione sotto i 2 non è una riunione)')

const rounds = args?.rounds || [
  { title: 'Apertura', instruction: 'Esponi la tua posizione iniziale dal tuo ruolo. Solo il topic, ancora nessuno ti ha preceduto in questo dibattito.' },
  { title: 'Replica', instruction: 'Ribatti PER NOME ad almeno un punto di un altro speaker nel transcript. Concedi dove ha ragione, tieni il punto dove no.' },
  { title: 'Posizione finale', instruction: 'Posizione finale: tieni il punto, concedi, o proponi un compromesso concreto. È il round che deve muovere verso una decisione.' },
]

const langLine = args?.lang ? `Scrivi in ${args.lang}.` : 'Scrivi nella stessa lingua del topic.'

// Regole d'ingaggio comuni a ogni speaker, ogni turno.
const engage = `Resta nel tuo ruolo. 100-200 parole, non di più. Ribatti per nome a chi non condividi. Concedi se l'altro ha ragione. NON fabbricare accordo che non c'è. ${langLine}`

// Costruisce il prompt di uno speaker per un dato round, col transcript accumulato.
function speakerPrompt(sp, round, transcript) {
  const personaBlock = sp.persona ? `Il tuo ruolo/persona in questa riunione:\n${sp.persona}\n\n` : ''
  const transcriptBlock = transcript
    ? `\n\n=== TRANSCRIPT FINORA (leggilo prima di parlare) ===\n${transcript}\n=== fine transcript ===`
    : ''
  return `${personaBlock}Sei "${sp.role}" in una riunione aziendale.\nTOPIC: ${topic}\n\nRound "${round.title}": ${round.instruction}\n${engage}${transcriptBlock}\n\nRispondi SOLO col tuo intervento (niente meta-commento, niente markdown di intestazione).`
}

phase('Dibattito')

// Il cuore: strettamente sequenziale. Transcript è una stringa che cresce.
// Ogni speaker di ogni round legge tutto ciò che è stato detto prima di lui,
// inclusi gli speaker precedenti DELLO STESSO round. È esattamente il dibattito
// che il Leader faceva a mano — qui è un doppio for deterministico.
let transcript = ''
const roundLog = []
for (const round of rounds) {
  let roundText = `\n## Round — ${round.title}\n`
  for (const sp of speakers) {
    const opts = { label: `${round.title}:${sp.role}`, phase: 'Dibattito', model: sp.model }
    if (sp.agentType) opts.agentType = sp.agentType
    const say = await agent(speakerPrompt(sp, round, transcript.trim()), opts)
    const block = `\n**${sp.role}:**\n${say || '(nessuna risposta)'}\n`
    roundText += block
    transcript += block   // subito visibile allo speaker successivo, stesso round
  }
  roundLog.push({ round: round.title, text: roundText })
}

phase('Verbale')

// Il moderatore NON parafrasa il Leader: legge il transcript completo e produce
// le minute. Un solo agente, fascia alta di default.
const verbale = await agent(
  `Sei il MODERATORE di questa riunione. Hai il transcript completo qui sotto. Produci un VERBALE sintetico in Markdown con queste sezioni, in quest'ordine:\n\n## Decisione\n(SOLO se è emerso consenso o maggioranza chiara — NON forzarla. Se non c'è, scrivi "Nessuna decisione: vedi disaccordi aperti".)\n\n## Disaccordi aperti\n(Verbatim: chi sosteneva cosa. NON appiattire le posizioni divergenti.)\n\n## Action item\n(Ciascuno con un owner mappato a un ruolo/speaker presente. Se non ci sono, dillo.)\n\n## Da portare a un umano\n(Ciò che gli agenti NON hanno risolto e serve al founder.)\n\n${langLine}\n\n=== TRANSCRIPT ===\n${transcript.trim()}\n=== fine ===`,
  { label: 'moderatore', phase: 'Verbale', model: args?.moderatorModel || 'opus' }
)

// Ritorno strutturato: il comando salva questi due su disco e li presenta.
const fullTranscript = `# Riunione — ${topic}\n${roundLog.map(r => r.text).join('\n')}`
return { topic, transcript: fullTranscript, verbale: verbale || '(verbale non prodotto)' }
