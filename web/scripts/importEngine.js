// High-resilience, Universal CSV & Excel Import Engine for QuizPro
// Supports arbitrary CSV dialects, multi-line rows, single/multiple option formats, and intelligent column inference.

export function normalizeHeader(header) {
  if (!header) return '';
  return header
    .toString()
    .replace(/^\uFEFF/, '')
    .replace(/^ï»¿/, '')
    .trim()
    .replace(/([a-z0-9])([A-Z])/g, '$1_$2') // Handle CamelCase to snake_case (e.g. OptionA -> Option_A)
    .toLowerCase()
    .replace(/[\s\-_/.]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

// Auto-detect whether file uses Comma, Semicolon, or Tab
function detectDelimiter(text) {
  const lines = text.split(/\r?\n/).slice(0, 10).join('\n');
  let commas = 0;
  let semis = 0;
  let tabs = 0;
  let inQuotes = false;

  for (let i = 0; i < lines.length; i++) {
    const c = lines[i];
    if (c === '"') {
      inQuotes = !inQuotes;
    } else if (!inQuotes) {
      if (c === ',') commas++;
      else if (c === ';') semis++;
      else if (c === '\t') tabs++;
    }
  }

  if (tabs > commas && tabs > semis) return '\t';
  if (semis > commas) return ';';
  return ',';
}

// RFC 4180 compliant CSV Parser with Dialect Detection
export function parseCSVString(text) {
  if (!text) return [];
  // Strip UTF-8 BOM
  if (text.charCodeAt(0) === 0xFEFF) {
    text = text.slice(1);
  } else if (text.startsWith('ï»¿')) {
    text = text.slice(3);
  }

  const delimiter = detectDelimiter(text);
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
      } else if (char === delimiter) {
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

// Comprehensive Header Aliases Dictionary
export const ALIASES = {
  question: [
    'question', 'questions', 'question_text', 'questiontext', 'q', 'prompt', 'item', 'items',
    'title', 'problem', 'query', 'description', 'question_title', 'question_name', 'mcq', 'text', 'q_text', 'qtext'
  ],
  question_type: [
    'question_type', 'type', 'qtype', 'item_type', 'mode', 'format'
  ],
  option_a: [
    'option_a', 'optiona', 'option_1', 'option1', 'choice_a', 'choicea', 'choice_1', 'choice1',
    'a', 'opt_a', 'opta', 'opt1', 'opt_1', 'ans_a', 'ansa', 'answer_a', 'answera', 'option_a_text'
  ],
  option_b: [
    'option_b', 'optionb', 'option_2', 'option2', 'choice_b', 'choiceb', 'choice_2', 'choice2',
    'b', 'opt_b', 'optb', 'opt2', 'opt_2', 'ans_b', 'ansb', 'answer_b', 'answerb', 'option_b_text'
  ],
  option_c: [
    'option_c', 'optionc', 'option_3', 'option3', 'choice_c', 'choicec', 'choice_3', 'choice3',
    'c', 'opt_c', 'optc', 'opt3', 'opt_3', 'ans_c', 'ansc', 'answer_c', 'answerc', 'option_c_text'
  ],
  option_d: [
    'option_d', 'optiond', 'option_4', 'option4', 'choice_d', 'choiced', 'choice_4', 'choice4',
    'd', 'opt_d', 'optd', 'opt4', 'opt_4', 'ans_d', 'ansd', 'answer_d', 'answerd', 'option_d_text'
  ],
  option_e: [
    'option_e', 'optione', 'option_5', 'option5', 'choice_e', 'choicee', 'choice_5', 'choice5',
    'e', 'opt_e', 'opte', 'opt5', 'opt_5', 'ans_e', 'anse', 'answer_e', 'answere'
  ],
  option_f: [
    'option_f', 'optionf', 'option_6', 'option6', 'choice_f', 'choicef', 'choice_6', 'choice6',
    'f', 'opt_f', 'optf', 'opt6', 'opt_6', 'ans_f', 'ansf', 'answer_f', 'answerf'
  ],
  options_combined: [
    'options', 'choices', 'all_options', 'option_list', 'choices_list', 'answers_list'
  ],
  correct: [
    'correct_answer', 'correct_answers', 'correct_option', 'correct_options', 'correct', 'correctanswer',
    'correctoption', 'answer', 'answers', 'key', 'keys', 'ans', 'correct_ans', 'right_answer',
    'right_option', 'solution', 'solution_key', 'correctchoice', 'correct_choice', 'is_correct', 'ans_key'
  ],
  explanation_a: ['explanation_a', 'exp_a', 'rationale_a', 'expa', 'explanationa'],
  explanation_b: ['explanation_b', 'exp_b', 'rationale_b', 'expb', 'explanationb'],
  explanation_c: ['explanation_c', 'exp_c', 'rationale_c', 'expc', 'explanationc'],
  explanation_d: ['explanation_d', 'exp_d', 'rationale_d', 'expd', 'explanationd'],
  explanation_e: ['explanation_e', 'exp_e', 'rationale_e'],
  explanation_f: ['explanation_f', 'exp_f', 'rationale_f'],
  explanation: [
    'explanation', 'explanations', 'rationale', 'rationales', 'notes', 'note', 'feedback',
    'solution_detail', 'why', 'exp', 'reason', 'justification', 'comment'
  ],
  topic: [
    'topic', 'topics', 'category', 'categories', 'subject', 'subjects', 'domain', 'domains',
    'tag', 'tags', 'module', 'unit', 'section'
  ],
  chapter: [
    'chapter', 'chapter_name', 'chapter_title', 'chap', 'ch', 'chapter_no', 'chap_no', 'lesson'
  ],
  difficulty: ['difficulty', 'level', 'diff', 'rating', 'hardness'],
  tags: ['tags', 'tag', 'keywords', 'keyword']
};

export function processRows(rows, filename = 'import.csv', existingQuestions = new Set()) {
  const issues = [];
  const validQuestions = [];
  let duplicateCount = 0;

  if (!rows || rows.length === 0) {
    return {
      validQuestions: [],
      issues: [{ row: 0, problem: 'File is completely empty', suggestion: 'Provide data rows with question and options', isWarning: false }],
      duplicateCount: 0,
      filename
    };
  }

  // 1. Scan the first 10 rows to locate the header row
  let columnMap = {};
  let startRow = 0;

  for (let i = 0; i < Math.min(rows.length, 10); i++) {
    const row = rows[i];
    if (!row || row.length === 0) continue;

    let foundQ = false;
    let foundOpt = false;
    let foundAns = false;
    const tempMap = {};

    for (let c = 0; c < row.length; c++) {
      const norm = normalizeHeader(row[c]);
      if (!norm) continue;

      for (const [key, aliasList] of Object.entries(ALIASES)) {
        if (aliasList.includes(norm)) {
          tempMap[key] = c;
          if (key === 'question') foundQ = true;
          if (key.startsWith('option_') || key === 'options_combined') foundOpt = true;
          if (key === 'correct') foundAns = true;
          break;
        }
      }
    }

    if ((foundQ && foundOpt) || (foundQ && foundAns)) {
      columnMap = tempMap;
      startRow = i + 1;
      break;
    }
  }

  // 2. Intelligent Content-Based Column Inference if no header detected
  if (Object.keys(columnMap).length === 0) {
    const sampleRow = rows.find(r => r && r.length >= 3 && r.some(c => c && c.length > 5)) || rows[0];
    
    if (sampleRow) {
      // Check if Column 0 is a row index/number (#, 1, 2, 3...)
      const col0IsNum = /^\d+$/.test(sampleRow[0]?.trim());
      const offset = col0IsNum ? 1 : 0;

      if (sampleRow.length >= offset + 3) {
        columnMap.question = offset;
        columnMap.option_a = offset + 1;
        columnMap.option_b = offset + 2;
        if (sampleRow.length > offset + 3) columnMap.option_c = offset + 3;
        if (sampleRow.length > offset + 4) columnMap.option_d = offset + 4;
        
        // Find answer column: look for column containing single char (A-F, 1-6) or "true/false"
        let foundAnsIdx = -1;
        for (let c = sampleRow.length - 1; c > offset; c--) {
          const val = sampleRow[c]?.trim().toUpperCase();
          if (/^[A-F1-6]$/.test(val) || val === 'TRUE' || val === 'FALSE') {
            foundAnsIdx = c;
            break;
          }
        }
        
        columnMap.correct = foundAnsIdx !== -1 ? foundAnsIdx : (sampleRow.length > offset + 5 ? offset + 5 : offset + 3);
        
        // If row 0 looks like header text, skip it
        const row0Col0 = rows[0][offset]?.toLowerCase() || '';
        if (row0Col0.includes('question') || row0Col0.includes('prompt') || row0Col0 === 'q') {
          startRow = 1;
        } else {
          startRow = 0;
        }
      }
    }

    // Ultimate fallback if still empty
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
  }

  const seenInFile = new Set();

  // 3. Process Data Rows
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
    let oA = getCol('option_a');
    let oB = getCol('option_b');
    let oC = getCol('option_c');
    let oD = getCol('option_d');
    let oE = getCol('option_e');
    let oF = getCol('option_f');
    const combinedOptions = getCol('options_combined');
    const correctRaw = getCol('correct');
    const expA = getCol('explanation_a');
    const expB = getCol('explanation_b');
    const expC = getCol('explanation_c');
    const expD = getCol('explanation_d');
    const expE = getCol('explanation_e');
    const expF = getCol('explanation_f');
    const genExp = getCol('explanation');
    const topic = getCol('topic') || 'General';
    const chapter = getCol('chapter') || '';
    const diffRaw = parseInt(getCol('difficulty'), 10);
    const tagsRaw = getCol('tags');

    // Skip entirely empty question lines
    if (!qText && !oA && !oB && !combinedOptions) continue;

    if (!qText) {
      issues.push({
        row: rowNum,
        problem: 'Missing question text',
        suggestion: 'Provide question prompt in the question column',
        rawData: r.slice(0, 4).join(' | '),
        isWarning: false
      });
      continue;
    }

    const normQ = qText.toLowerCase();
    if (seenInFile.has(normQ)) {
      issues.push({
        row: rowNum,
        problem: `Duplicate question within file ("${qText.slice(0, 40)}...")`,
        suggestion: 'Remove duplicate question row to maintain test integrity',
        rawData: qText,
        isWarning: false
      });
      continue;
    }
    seenInFile.add(normQ);

    if (existingQuestions.has(normQ)) {
      duplicateCount++;
      issues.push({
        row: rowNum,
        problem: `Question already exists in target exam ("${qText.slice(0, 40)}...")`,
        suggestion: 'Question will be appended anyway or can be skipped',
        rawData: qText,
        isWarning: true
      });
    }

    // Build Options Array
    const options = [];
    if (oA) options.push(oA);
    if (oB) options.push(oB);
    if (oC) options.push(oC);
    if (oD) options.push(oD);
    if (oE) options.push(oE);
    if (oF) options.push(oF);

    // If options were not found in separate columns, check single combined column
    if (options.length < 2 && combinedOptions) {
      let splitOpts = combinedOptions.split(/\r?\n/).map(s => s.trim()).filter(Boolean);
      if (splitOpts.length < 2 && combinedOptions.includes('|')) {
        splitOpts = combinedOptions.split('|').map(s => s.trim()).filter(Boolean);
      }
      if (splitOpts.length < 2 && /[A-Fa-f][.)]\s+/.test(combinedOptions)) {
        splitOpts = combinedOptions.split(/(?=[A-Fa-f][.)]\s+)/).map(s => s.replace(/^[A-Fa-f][.)]\s+/, '').trim()).filter(Boolean);
      }
      if (splitOpts.length < 2 && /\d+[.)]\s+/.test(combinedOptions)) {
        splitOpts = combinedOptions.split(/(?=\d+[.)]\s+)/).map(s => s.replace(/^\d+[.)]\s+/, '').trim()).filter(Boolean);
      }
      if (splitOpts.length >= 2) {
        options.push(...splitOpts);
      }
    }

    // Clean option prefix if user embedded "A. ", "B) ", etc.
    const cleanedOptions = options.map(opt => {
      return opt.replace(/^[A-Fa-f1-6][.)]\s+/, '').trim();
    });

    if (cleanedOptions.length < 2) {
      issues.push({
        row: rowNum,
        problem: 'Fewer than 2 options provided',
        suggestion: 'Question requires at least 2 distinct choices (Option A and Option B)',
        rawData: `Question: "${qText.slice(0, 30)}..." | Options: [${options.join(', ')}]`,
        isWarning: false
      });
      continue;
    }

    if (!correctRaw) {
      issues.push({
        row: rowNum,
        problem: 'Missing correct answer',
        suggestion: 'Specify correct answer (e.g. A, B, C, D, or 1, 2, 3, 4)',
        rawData: `Question: "${qText.slice(0, 30)}..."`,
        isWarning: false
      });
      continue;
    }

    // Parse Correct Answers with Universal Flexibility
    const correctAnswers = new Set();
    const cleanCorrect = correctRaw.toString().trim();
    const letterMap = { a: 0, b: 1, c: 2, d: 3, e: 4, f: 5 };

    // Split multi-select tokens by separators: comma, pipe, semicolon, slash, "and", "&"
    const rawTokens = cleanCorrect
      .replace(/\band\b/gi, ',')
      .replace(/&/g, ',')
      .split(/[|,;/+]+/)
      .map(t => t.trim())
      .filter(Boolean);

    for (const tok of rawTokens) {
      const lowerTok = tok.toLowerCase();
      // Remove prefixes like "option ", "choice ", "ans: ", etc.
      const stripped = lowerTok
        .replace(/^(option|choice|ans|answer|key)[:\s]+/i, '')
        .replace(/[()[\]{}.:]/g, '')
        .trim();

      // 1. Single letter A-F
      if (letterMap[stripped] !== undefined && letterMap[stripped] < cleanedOptions.length) {
        correctAnswers.add(letterMap[stripped]);
        continue;
      }

      // 2. Number 1-6 (1-based index)
      const num = parseInt(stripped, 10);
      if (!isNaN(num) && num >= 1 && num <= cleanedOptions.length) {
        correctAnswers.add(num - 1);
        continue;
      }

      // 3. Number 0 (0-based index if user uses 0, 1, 2)
      if (stripped === '0' && cleanedOptions.length > 0) {
        correctAnswers.add(0);
        continue;
      }

      // 4. True / False matching
      if ((stripped === 'true' || stripped === 't') && cleanedOptions.some(o => o.toLowerCase() === 'true')) {
        const idx = cleanedOptions.findIndex(o => o.toLowerCase() === 'true');
        if (idx >= 0) correctAnswers.add(idx);
        continue;
      }
      if ((stripped === 'false' || stripped === 'f') && cleanedOptions.some(o => o.toLowerCase() === 'false')) {
        const idx = cleanedOptions.findIndex(o => o.toLowerCase() === 'false');
        if (idx >= 0) correctAnswers.add(idx);
        continue;
      }

      // 5. Match exact option text
      const textMatchIdx = cleanedOptions.findIndex(opt => opt.toLowerCase() === stripped.toLowerCase() || opt.toLowerCase() === tok.toLowerCase());
      if (textMatchIdx >= 0) {
        correctAnswers.add(textMatchIdx);
        continue;
      }
    }

    // If still empty, try matching full correctRaw against option texts
    if (correctAnswers.size === 0) {
      const fullMatch = cleanedOptions.findIndex(opt => opt.toLowerCase() === cleanCorrect.toLowerCase());
      if (fullMatch >= 0) {
        correctAnswers.add(fullMatch);
      } else {
        issues.push({
          row: rowNum,
          problem: `Invalid correct answer "${cleanCorrect}"`,
          suggestion: `Must match A, B, C, D, or option text. Available options: [${cleanedOptions.map((o, idx) => String.fromCharCode(65 + idx)).join(', ')}]`,
          rawData: `Question: "${qText.slice(0, 30)}..." | Answer: "${cleanCorrect}"`,
          isWarning: false
        });
        continue;
      }
    }

    // Explanations mapping
    const optionExplanations = {};
    if (expA) optionExplanations[0] = expA;
    if (expB) optionExplanations[1] = expB;
    if (expC) optionExplanations[2] = expC;
    if (expD) optionExplanations[3] = expD;
    if (expE) optionExplanations[4] = expE;
    if (expF) optionExplanations[5] = expF;

    if (genExp && Object.keys(optionExplanations).length === 0) {
      const firstCorrect = Array.from(correctAnswers)[0] || 0;
      optionExplanations[firstCorrect] = genExp;
    }

    const tags = tagsRaw ? tagsRaw.split(/[,;|]/).map(t => t.trim()).filter(Boolean) : [];
    let questionType = 'single';
    if (qTypeRaw.includes('multi') || correctAnswers.size > 1) {
      questionType = 'multiple';
    } else if (qTypeRaw.includes('true') || qTypeRaw === 'tf' || qTypeRaw === 'boolean' || (cleanedOptions.length === 2 && cleanedOptions[0].toLowerCase() === 'true' && cleanedOptions[1].toLowerCase() === 'false')) {
      questionType = 'true_false';
    }
    const difficulty = isNaN(diffRaw) || diffRaw < 1 || diffRaw > 5 ? 3 : diffRaw;

    validQuestions.push({
      id: 'imp_' + Date.now() + '_' + i,
      displayNumber: validQuestions.length + 1,
      question: qText,
      questionType,
      options: cleanedOptions,
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
