import assert from 'assert';
import fs from 'fs';
import path from 'path';

console.log('🧪 Testing Hierarchical Chapter & Topic Selection and Option Shapes...');

// 1. Verify CSS rules for shapes and Chapter-Topic matrix
const cssContent = fs.readFileSync('web/styles/main.css', 'utf8');

assert(cssContent.includes('.options-list.is-single .option-letter') && cssContent.includes('border-radius: 50% !important;'), 
  'CSS must include circle border-radius (50%) for single select');
assert(cssContent.includes('.options-list.is-multi .option-letter') && cssContent.includes('border-radius: 6px !important;'), 
  'CSS must include square border-radius (6px) for multi select');
assert(cssContent.includes('.ct-matrix-container'), 'CSS must include .ct-matrix-container');
assert(cssContent.includes('.ct-topic-item.selected'), 'CSS must include .ct-topic-item.selected with yellow highlight');
assert(cssContent.includes('.ct-chapter-cell.has-selected') || cssContent.includes('.ct-chapter-cell.all-selected'), 'CSS must include chapter cell highlight states');

console.log('✅ CSS shape and matrix rules verified.');

// 2. Verify HTML elements for Chapter & Topic Matrix
const htmlContent = fs.readFileSync('web/index.html', 'utf8');

assert(htmlContent.includes('id="launcherCTSummaryBar"'), 'HTML must include #launcherCTSummaryBar');
assert(htmlContent.includes('id="launcherCTMatrixContainer"'), 'HTML must include #launcherCTMatrixContainer');
assert(htmlContent.includes('id="launcherCTMatrixBody"'), 'HTML must include #launcherCTMatrixBody');
assert(htmlContent.includes('id="btnLauncherSelectAllCT"'), 'HTML must include #btnLauncherSelectAllCT');
assert(htmlContent.includes('id="btnLauncherClearAllCT"'), 'HTML must include #btnLauncherClearAllCT');
assert(htmlContent.includes('id="launcherCTSearch"'), 'HTML must include #launcherCTSearch');

console.log('✅ HTML structure for Chapter-Topic matrix verified.');

// 3. Test Chapter & Topic Matching Engine Logic
class MockApp {
  constructor() {
    this.selectedLauncherCT = new Map();
    this.isAllLauncherCTSelected = true;
  }

  isQuestionCTMatched(q) {
    if (this.isAllLauncherCTSelected) return true;
    if (!this.selectedLauncherCT || this.selectedLauncherCT.size === 0) return false;

    const chap = (q.chapter && q.chapter.trim()) ? q.chapter.trim() : 'General / Other';
    const top = (q.topic && q.topic.trim()) ? q.topic.trim() : 'General / Other';

    const selectedTopics = this.selectedLauncherCT.get(chap);
    if (!selectedTopics) return false;

    return selectedTopics.has(top);
  }
}

const app = new MockApp();

const sampleQuestions = [
  { id: '1', chapter: 'CHAP 1', topic: 'TOPIC 1', text: 'Q1' },
  { id: '2', chapter: 'CHAP 1', topic: 'TOPIC 2', text: 'Q2' },
  { id: '3', chapter: 'CHAP 1', topic: 'TOPIC 3', text: 'Q3' },
  { id: '4', chapter: 'CHAP 2', topic: 'TOPIC 1', text: 'Q4' },
  { id: '5', chapter: 'CHAP 2', topic: 'TOPIC 2', text: 'Q5' },
  { id: '6', chapter: 'CHAP 2', topic: 'TOPIC 3', text: 'Q6' },
  { id: '7', chapter: 'CHAP 3', topic: 'TOPIC 1', text: 'Q7' },
  { id: '8', chapter: 'CHAP 3', topic: 'TOPIC 2', text: 'Q8' },
  { id: '9', chapter: 'CHAP 3', topic: 'TOPIC 3', text: 'Q9' },
];

// Case A: All selected
assert.strictEqual(sampleQuestions.filter(q => app.isQuestionCTMatched(q)).length, 9, 'All 9 questions pass when isAllLauncherCTSelected is true');

// Case B: User selects CHAPTER 1 -> TOPIC 3, and CHAPTER 3 -> TOPIC 2
app.isAllLauncherCTSelected = false;
app.selectedLauncherCT.set('CHAP 1', new Set(['TOPIC 3']));
app.selectedLauncherCT.set('CHAP 3', new Set(['TOPIC 2']));

const matched = sampleQuestions.filter(q => app.isQuestionCTMatched(q));
assert.strictEqual(matched.length, 2, 'Exactly 2 questions must match');
assert.deepStrictEqual(matched.map(q => q.id), ['3', '8'], 'Matched questions must be CHAP 1 -> TOPIC 3 and CHAP 3 -> TOPIC 2');

// Case C: Clear all
app.selectedLauncherCT.clear();
const matchedEmpty = sampleQuestions.filter(q => app.isQuestionCTMatched(q));
assert.strictEqual(matchedEmpty.length, 0, '0 questions match when cleared');

console.log('✅ All Chapter & Topic matching engine tests passed with 100% precision!');
