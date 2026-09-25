// High-resilience CSV & Excel Import Engine matching QuizPro specifications

function normalizeHeader(header) {
  if (!header) return '';
  return header
    .toString()
    .replace(/^\uFEFF/, '')
    .replace(/^ï»¿/, '')
    .trim()
    .toLowerCase()
    .replace(/[\s\-_/]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

// RFC 4180 compliant CSV Parser
export function parseCSVString(text) {
  if (!text) return [];
  // Strip BOM
  if (text.charCodeAt(0) === 0xFEFF) {
    text = text.slice(1);
  }
  
  const rows = [];
  let currentRow = [];
  let currentVal = '';
  let inQuotes = false;

  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    const nextChar = text[i + 1];

    if (inQuotes) {
      if (char === '"') {
        if (nextChar === '"') {
          currentVal += '"';
          i++; // Skip escaped quote
        } else {
          inQuotes = false;
        }
      } else {
        currentVal += char;
      }
    } else {
      if (char === '"') {
        inQuotes = true;
      } else if (char === ',' || char === '\t' || char === ';') {
        currentRow.push(currentVal.trim());
        currentVal = '';
      } else if (char === '\r') {
        if (nextChar === '\n') i++;
        currentRow.push(currentVal.trim());
        rows.push(currentRow);
        currentRow = [];
        currentVal = '';
      } else if (char === '\n') {
        currentRow.push(currentVal.trim());
        rows.push(currentRow);
        currentRow = [];
        currentVal = '';
      } else {
        currentVal += char;
      }
    }
  }

  if (currentVal.length > 0 || currentRow.length > 0) {
    currentRow.push(currentVal.trim());
    rows.push(currentRow);
  }

  return rows.filter(r => r.some(cell => cell && cell.length > 0));
}

// Header Aliases
const ALIASES = {
  question: ['question', 'question_text', 'questiontext', 'q', 'prompt', 'item'],
  question_type: ['question_type', 'type', 'qtype', 'item_type'],
  option_a: ['option_a', 'option_1', 'choice_a', 'a', 'opt_a', 'choice_1'],
  option_b: ['option_b', 'option_2', 'choice_b', 'b', 'opt_b', 'choice_2'],
  option_c: ['option_c', 'option_3', 'choice_c', 'c', 'opt_c', 'choice_3'],
  option_d: ['option_d', 'option_4', 'choice_d', 'd', 'opt_d', 'choice_4'],
  correct: ['correct_answer', 'correct_option', 'correct', 'answer', 'key', 'ans'],
  explanation_a: ['explanation_a', 'exp_a', 'rationale_a'],
  explanation_b: ['explanation_b', 'exp_b', 'rationale_b'],
  explanation_c: ['explanation_c', 'exp_c', 'rationale_c'],
  explanation_d: ['explanation_d', 'exp_d', 'rationale_d'],
  explanation: ['explanation', 'rationale', 'notes', 'feedback'],
  topic: ['topic', 'category', 'subject', 'domain'],
  chapter: ['chapter', 'chapter_name', 'chapter_title', 'chap', 'ch'],
  difficulty: ['difficulty', 'level', 'diff'],
  tags: ['tags', 'tag', 'keywords']
};

export function processRows(rows, filename = 'import.csv', existingQuestions = new Set()) {
  const issues = [];
  const validQuestions = [];
  let duplicateCount = 0;

  if (!rows || rows.length === 0) {
    return {
      validQuestions: [],
      issues: [{ row: 0, problem: 'File is completely empty', suggestion: 'Provide data rows', isWarning: false }],
      duplicateCount: 0,
      filename
    };
  }

  // 1. Identify Headers
  let columnMap = {};
  let startRow = 0;

  for (let i = 0; i < Math.min(rows.length, 5); i++) {
    const row = rows[i];
    let foundQ = false;
    let foundOpt = false;
    const tempMap = {};

    for (let c = 0; c < row.length; c++) {
      const norm = normalizeHeader(row[c]);
      if (!norm) continue;

      for (const [key, aliasList] of Object.entries(ALIASES)) {
        if (aliasList.includes(norm)) {
          tempMap[key] = c;
          if (key === 'question') foundQ = true;
          if (key.startsWith('option_')) foundOpt = true;
          break;
        }
      }
    }

    if (foundQ && foundOpt) {
      columnMap = tempMap;
      startRow = i + 1;
      break;
    }
  }

  // Positional fallback if no recognized header
  if (Object.keys(columnMap).length === 0) {
    columnMap = {
      question: 0,
      option_a: 1,
      option_b: 2,
      option_c: 3,
      option_d: 4,
      correct: 5,
      explanation: 6,
      topic: 7,
      difficulty: 8,
      tags: 9
    };
    startRow = 0;
  }

  const seenInFile = new Set();

  for (let i = startRow; i < rows.length; i++) {
    const r = rows[i];
    if (!r || r.length === 0 || r.every(cell => !cell || !cell.toString().trim())) continue;
    const rowNum = i + 1;

    const getCol = (key) => {
      const idx = columnMap[key];
      if (idx === undefined || idx >= r.length || r[idx] === undefined) return '';
      return r[idx].toString().trim();
    };

    const qText = getCol('question');
    const qTypeRaw = getCol('question_type').toLowerCase();
    const oA = getCol('option_a');
    const oB = getCol('option_b');
    const oC = getCol('option_c');
    const oD = getCol('option_d');
    const correctRaw = getCol('correct');
    const expA = getCol('explanation_a');
    const expB = getCol('explanation_b');
    const expC = getCol('explanation_c');
    const expD = getCol('explanation_d');
    const genExp = getCol('explanation');
    const topic = getCol('topic') || 'General';
    const chapter = getCol('chapter') || '';
    const diffRaw = parseInt(getCol('difficulty'), 10);
    const tagsRaw = getCol('tags');

    if (!qText && !oA && !oB) continue;

    if (!qText) {
      issues.push({ row: rowNum, problem: 'Missing question prompt', suggestion: 'Provide question text', isWarning: false });
      continue;
    }

    const normQ = qText.toLowerCase();
    if (seenInFile.has(normQ)) {
      issues.push({ row: rowNum, problem: `Duplicate question within file ("${qText}")`, suggestion: 'Remove duplicate question row', isWarning: false });
      continue;
    }
    seenInFile.add(normQ);

    if (existingQuestions.has(normQ)) {
      duplicateCount++;
      issues.push({ row: rowNum, problem: `Question already exists in exam`, suggestion: 'Verify if duplicate is intended', isWarning: true });
    }

    const options = [];
    if (oA) options.push(oA);
    if (oB) options.push(oB);
    if (oC) options.push(oC);
    if (oD) options.push(oD);

    if (options.length < 2) {
      issues.push({ row: rowNum, problem: 'Requires at least 2 options', suggestion: 'Provide at least Option A and Option B', isWarning: false });
      continue;
    }

    if (!correctRaw) {
      issues.push({ row: rowNum, problem: 'Missing correct answer', suggestion: 'Specify correct answer (e.g. A, B, 1, 2, or A|B)', isWarning: false });
      continue;
    }

    // Parse correct answers
    const correctAnswers = new Set();
    const tokens = correctRaw.split(/[|,;/+&\s]+/).map(t => t.trim().toLowerCase()).filter(Boolean);

    // Check if user is using 0-based indexing (e.g. answer is "0")
    const usesZeroIndex = tokens.includes('0');

    tokens.forEach(tok => {
      if (usesZeroIndex) {
        if (tok === '0' && options.length > 0) correctAnswers.add(0);
        else if (tok === '1' && options.length > 1) correctAnswers.add(1);
        else if (tok === '2' && options.length > 2) correctAnswers.add(2);
        else if (tok === '3' && options.length > 3) correctAnswers.add(3);
      } else {
        if ((tok === 'a' || tok === '1') && options.length > 0) correctAnswers.add(0);
        else if ((tok === 'b' || tok === '2') && options.length > 1) correctAnswers.add(1);
        else if ((tok === 'c' || tok === '3') && options.length > 2) correctAnswers.add(2);
        else if ((tok === 'd' || tok === '4') && options.length > 3) correctAnswers.add(3);
      }

      // Check for true/false representations
      if ((tok === 'true' || tok === 't') && options.some(o => o.toLowerCase() === 'true')) {
        const idx = options.findIndex(o => o.toLowerCase() === 'true');
        if (idx >= 0) correctAnswers.add(idx);
      } else if ((tok === 'false' || tok === 'f') && options.some(o => o.toLowerCase() === 'false')) {
        const idx = options.findIndex(o => o.toLowerCase() === 'false');
        if (idx >= 0) correctAnswers.add(idx);
      }

      // Exact match option text check
      const matchIdx = options.findIndex(opt => opt.toLowerCase() === tok);
      if (matchIdx >= 0) correctAnswers.add(matchIdx);
    });

    if (correctAnswers.size === 0) {
      // Check full string match against option text
      const fullMatch = options.findIndex(opt => opt.toLowerCase() === correctRaw.toLowerCase());
      if (fullMatch >= 0) {
        correctAnswers.add(fullMatch);
      } else {
        issues.push({ row: rowNum, problem: `Invalid correct answer "${correctRaw}"`, suggestion: 'Set to A, B, C, D or 1, 2, 3, 4', isWarning: false });
        continue;
      }
    }

    // Explanations mapping
    const optionExplanations = {};
    if (expA) optionExplanations[0] = expA;
    if (expB) optionExplanations[1] = expB;
    if (expC) optionExplanations[2] = expC;
    if (expD) optionExplanations[3] = expD;

    if (genExp && Object.keys(optionExplanations).length === 0) {
      const firstCorrect = Array.from(correctAnswers)[0] || 0;
      optionExplanations[firstCorrect] = genExp;
    }

    const tags = tagsRaw ? tagsRaw.split(/[,;|]/).map(t => t.trim()).filter(Boolean) : [];
    const questionType = qTypeRaw === 'multiple' || correctAnswers.size > 1 ? 'multiple' : 'single';
    const difficulty = isNaN(diffRaw) || diffRaw < 1 || diffRaw > 5 ? 3 : diffRaw;

    validQuestions.push({
      id: 'imp_' + Date.now() + '_' + i,
      displayNumber: validQuestions.length + 1,
      question: qText,
      questionType,
      options,
      correctAnswers: Array.from(correctAnswers),
      optionExplanations,
      explanation: genExp,
      topic,
      chapter,
      difficulty,
      tags
    });
  }

  return {
    validQuestions,
    issues,
    duplicateCount,
    filename
  };
}

export function parseExcelArrayBuffer(buffer, filename, existingQuestions = new Set()) {
  if (!window.XLSX) {
    throw new Error('SheetJS library is not loaded.');
  }
  const workbook = window.XLSX.read(buffer, { type: 'array' });
  const firstSheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[firstSheetName];
  const rows = window.XLSX.utils.sheet_to_json(sheet, { header: 1 });
  return processRows(rows, filename, existingQuestions);
}

export function generateSampleCsvContent() {
  const headers = ['question', 'option_a', 'option_b', 'option_c', 'option_d', 'correct_answer', 'explanation', 'topic', 'difficulty', 'tags'];
  const samples = [
    [
      'What is the primary function of DNS in computer networking?',
      'Encrypt web traffic',
      'Translate domain names to IP addresses',
      'Manage database transactions',
      'Route physical electricity',
      'B',
      'DNS resolves human-readable names like example.com into machine-routable IP addresses.',
      'Networking',
      '1',
      'DNS; Internet; Protocols'
    ],
    [
      'Which of the following are ACID properties in database management? (Select TWO)',
      'Atomicity',
      'Scalability',
      'Isolation',
      'Portability',
      'A|C',
      'ACID stands for Atomicity, Consistency, Isolation, and Durability.',
      'Databases',
      '2',
      'SQL; ACID; Data'
    ]
  ];

  const escapeCSV = (str) => {
    if (str.includes(',') || str.includes('"') || str.includes('\n')) {
      return '"' + str.replace(/"/g, '""') + '"';
    }
    return str;
  };

  const lines = [headers.join(',')];
  samples.forEach(row => {
    lines.push(row.map(escapeCSV).join(','));
  });

  return lines.join('\n');
}
