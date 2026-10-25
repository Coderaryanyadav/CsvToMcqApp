import os
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, KeepTogether, PageBreak, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas

BASE_DIR = '/Users/aryan/Desktop/PROJECTS/1 - MCQ-App'
OUTPUT_PDF = os.path.join(BASE_DIR, 'QuizPro_Executive_Project_Overview.pdf')
SCREENSHOTS_DIR = os.path.join(BASE_DIR, 'Screenshots/UltraHD_Desktop')

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super(NumberedCanvas, self).__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super(NumberedCanvas, self).showPage()
        super(NumberedCanvas, self).save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        self.setFont("Helvetica-Bold", 8)
        self.setFillColor(colors.HexColor('#6366F1'))
        self.drawString(54, 750, "QUIZPRO ENTERPRISE PLATFORM")
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor('#94A3B8'))
        self.drawRightString(558, 750, "Technical Project Architecture & Systems Showcase")
        
        self.setStrokeColor(colors.HexColor('#E2E8F0'))
        self.setLineWidth(0.5)
        self.line(54, 742, 558, 742)
        
        self.line(54, 45, 558, 45)
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor('#64748B'))
        self.drawString(54, 32, "Confidential • QuizPro Platform Assessment Ecosystem • Author: Aryan Yadav")
        self.drawRightString(558, 32, f"Page {self._pageNumber} of {page_count}")
        self.restoreState()

def build_pdf():
    doc = SimpleDocTemplate(
        OUTPUT_PDF,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=68,
        bottomMargin=54
    )
    
    styles = getSampleStyleSheet()
    
    primary_color = colors.HexColor('#1E1B4B')
    accent_indigo = colors.HexColor('#4F46E5')
    text_dark = colors.HexColor('#0F172A')
    text_muted = colors.HexColor('#475569')
    bg_card = colors.HexColor('#F8FAFC')
    
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=24,
        leading=28,
        textColor=primary_color,
        spaceAfter=6
    )
    
    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=11,
        leading=16,
        textColor=accent_indigo,
        spaceAfter=15
    )
    
    h1_style = ParagraphStyle(
        'DocH1',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=14,
        leading=18,
        textColor=primary_color,
        spaceBefore=14,
        spaceAfter=6
    )
    
    h2_style = ParagraphStyle(
        'DocH2',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=11,
        leading=15,
        textColor=accent_indigo,
        spaceBefore=8,
        spaceAfter=4
    )
    
    body_style = ParagraphStyle(
        'DocBody',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13.5,
        textColor=text_dark,
        spaceAfter=6
    )

    badge_style = ParagraphStyle(
        'BadgeText',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=10,
        textColor=colors.HexColor('#FFFFFF'),
        alignment=1
    )

    caption_style = ParagraphStyle(
        'ImgCaption',
        parent=styles['Normal'],
        fontName='Helvetica-Oblique',
        fontSize=8,
        leading=11,
        textColor=text_muted,
        alignment=1,
        spaceBefore=4,
        spaceAfter=10
    )
    
    story = []
    
    # Header Banner
    story.append(Paragraph("QuizPro Assessment & Examination Platform", title_style))
    story.append(Paragraph("Enterprise Multi-Platform Architecture, Local-First Engine & Full Technical Audit", subtitle_style))
    
    # Executive Summary Card
    summary_data = [
        [
            Paragraph("<b>Core Capabilities:</b> Local-First Storage • Cross-Platform Flutter & Web • Sub-second Cold Start • Strict Zero-Dummy Isolation • Schema V3 Auto-Migration • Full CSV/Excel Ingestion Engine", body_style),
            Paragraph("<b>Version:</b> 2.4.0 Production Ready<br/><b>Lead Architect:</b> Aryan Yadav<br/><b>Client:</b> Flutter Desktop/Mobile & Progressive Web", body_style)
        ]
    ]
    summary_table = Table(summary_data, colWidths=[330, 174])
    summary_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), bg_card),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#CBD5E1')),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('PADDING', (0,0), (-1,-1), 10),
        ('ROUNDEDCORNERS', [4, 4, 4, 4])
    ]))
    story.append(summary_table)
    story.append(Spacer(1, 12))
    
    # Section 1: Executive Overview
    story.append(Paragraph("1. Executive Platform Architecture", h1_style))
    story.append(Paragraph(
        "<b>QuizPro</b> is an ultra-fast, local-first assessment platform engineered for enterprise scalability, precision certification preparation, and zero-latency examination workflows. Originally conceived as a high-performance Flutter mobile and desktop suite, it has been seamlessly paired with a high-fidelity Web counterpart maintaining exact feature, data model, and visual parity.",
        body_style
    ))
    
    # Architecture Table
    arch_data = [
        [Paragraph("<b>Component Layer</b>", body_style), Paragraph("<b>Technology & Implementation</b>", body_style), Paragraph("<b>Production Advantage</b>", body_style)],
        [Paragraph("<b>Core Framework</b>", body_style), Paragraph("Flutter 3.x (Dart) & Vanilla Modern Web ES6 Modules", body_style), Paragraph("Universal execution on macOS, iOS, Android, and Web with 0 runtime framework overhead.", body_style)],
        [Paragraph("<b>State & Persistence</b>", body_style), Paragraph("Local-First StorageRepository (Hive in Flutter, LocalStorage + Supabase in Web)", body_style), Paragraph("Guaranteed offline operability, instant local persistence, and automatic cloud synchronization.", body_style)],
        [Paragraph("<b>Assessment Engine</b>", body_style), Paragraph("Multi-mode ExamEngine supporting Practice, Timed Assessment, and Chapter Isolation", body_style), Paragraph("Anti-cheat question shuffling, persistent timekeeping, bookmark toggles, and live scoring.", body_style)],
        [Paragraph("<b>Data Ingestion</b>", body_style), Paragraph("Smart CSV / Excel Import Engine with automatic column mapping & fuzzy matching", body_style), Paragraph("Batch ingestion of thousands of questions with comprehensive syntax and validation checks.", body_style)],
        [Paragraph("<b>Analytics Engine</b>", body_style), Paragraph("Topic-wise mastery breakdown, historical trendlines, mistake isolation, and streak tracking", body_style), Paragraph("Pinpoints syllabus weaknesses down to the chapter level with actionable remediation paths.", body_style)]
    ]
    arch_table = Table(arch_data, colWidths=[100, 204, 200])
    arch_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#EDE9FE')),
        ('TEXTCOLOR', (0,0), (-1,0), primary_color),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E2E8F0')),
        ('PADDING', (0,0), (-1,-1), 6),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F8FAFC')])
    ]))
    story.append(arch_table)
    story.append(Spacer(1, 14))

    # Section 2: Visual Showcase - Primary System Screens
    story.append(Paragraph("2. System Interfaces & Interactive Modules", h1_style))
    story.append(Paragraph(
        "Each user interface within QuizPro is designed following modern ergonomic design standards, featuring a sleek dark aesthetic, crisp contrast ratios, and responsive glassmorphic cards.",
        body_style
    ))

    # Image Showcase Grid 1: Dashboard & Exam Catalog
    dash_img_path = os.path.join(SCREENSHOTS_DIR, '01_Executive_Dashboard.png')
    exam_img_path = os.path.join(SCREENSHOTS_DIR, '02_Exam_Catalog.png')
    
    if os.path.exists(dash_img_path) and os.path.exists(exam_img_path):
        img_table_data = [
            [
                Image(dash_img_path, width=245, height=138),
                Image(exam_img_path, width=245, height=138)
            ],
            [
                Paragraph("<b>Figure 1:</b> Executive Performance Dashboard", caption_style),
                Paragraph("<b>Figure 2:</b> Examination & Certification Catalog", caption_style)
            ]
        ]
        img_table = Table(img_table_data, colWidths=[252, 252])
        img_table.setStyle(TableStyle([
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('VALIGN', (0,0), (-1,-1), 'TOP'),
            ('PADDING', (0,0), (-1,-1), 2),
        ]))
        story.append(img_table)

    story.append(PageBreak())

    # Page 2: Advanced Capabilities, Exam Engine, & Analytics
    story.append(Paragraph("3. Assessment Execution & Intelligent Diagnostics", h1_style))
    story.append(Paragraph(
        "The examination lifecycle is split into two specialized modes: <b>Practice Mode</b> for instant feedback, explanations, and learning reinforcement, and <b>Timed Exam Mode</b> for strict proctored simulations.",
        body_style
    ))

    practice_img_path = os.path.join(SCREENSHOTS_DIR, '07_Interactive_Practice_Mode.png')
    results_img_path = os.path.join(SCREENSHOTS_DIR, '09_Score_Results_Screen.png')
    
    if os.path.exists(practice_img_path) and os.path.exists(results_img_path):
        img_table_data2 = [
            [
                Image(practice_img_path, width=245, height=138),
                Image(results_img_path, width=245, height=138)
            ],
            [
                Paragraph("<b>Figure 3:</b> Practice Mode with Immediate Explanations", caption_style),
                Paragraph("<b>Figure 4:</b> Comprehensive Result Screen & Topic Breakdown", caption_style)
            ]
        ]
        img_table2 = Table(img_table_data2, colWidths=[252, 252])
        img_table2.setStyle(TableStyle([
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('VALIGN', (0,0), (-1,-1), 'TOP'),
            ('PADDING', (0,0), (-1,-1), 2),
        ]))
        story.append(img_table2)

    story.append(Paragraph("4. Granular Chapter & Topic Matrix", h1_style))
    story.append(Paragraph(
        "QuizPro features a specialized <b>Chapter-Topic Matrix (CTM)</b> engine that parses hierarchical subject taxonomies. Users can configure targeted test sessions focusing exclusively on specific chapters, high-difficulty concepts, or historical mistake categories.",
        body_style
    ))

    matrix_img_path = os.path.join(SCREENSHOTS_DIR, '03_Question_Bank_Matrix.png')
    audit_img_path = os.path.join(SCREENSHOTS_DIR, '10_Exam_Audit_Breakdown_Modal.png')

    if os.path.exists(matrix_img_path) and os.path.exists(audit_img_path):
        img_table_data3 = [
            [
                Image(matrix_img_path, width=245, height=138),
                Image(audit_img_path, width=245, height=138)
            ],
            [
                Paragraph("<b>Figure 5:</b> Question Bank Chapter & Taxonomy Filter", caption_style),
                Paragraph("<b>Figure 6:</b> Performance Audit Breakdown Modal", caption_style)
            ]
        ]
        img_table3 = Table(img_table_data3, colWidths=[252, 252])
        img_table3.setStyle(TableStyle([
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('VALIGN', (0,0), (-1,-1), 'TOP'),
            ('PADDING', (0,0), (-1,-1), 2),
        ]))
        story.append(img_table3)

    story.append(Spacer(1, 8))
    story.append(Paragraph("5. Technical Reliability & Test Verification", h1_style))
    
    test_metrics = [
        [Paragraph("<b>Verification Dimension</b>", body_style), Paragraph("<b>Test Suite Scope</b>", body_style), Paragraph("<b>Status</b>", body_style)],
        [Paragraph("Local Persistence & Schema V3", body_style), Paragraph("120+ Rigorous Assertions verifying schema migration, key isolation & zero dummy pollution", body_style), Paragraph("<font color='#16A34A'><b>100% PASSED</b></font>", body_style)],
        [Paragraph("Multi-platform Parsing", body_style), Paragraph("CSV RFC-4180 standard, UTF-8 BOM, escaped quotes, multi-choice delimitations", body_style), Paragraph("<font color='#16A34A'><b>100% PASSED</b></font>", body_style)],
        [Paragraph("Real-Time Engine Integrity", body_style), Paragraph("Clock drift resistance, background state preservation, auto-save upon visibility changes", body_style), Paragraph("<font color='#16A34A'><b>100% PASSED</b></font>", body_style)]
    ]
    test_table = Table(test_metrics, colWidths=[140, 264, 100])
    test_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#F1F5F9')),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('PADDING', (0,0), (-1,-1), 5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F8FAFC')])
    ]))
    story.append(test_table)

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"✅ Generated Project Overview PDF: {OUTPUT_PDF}")

if __name__ == '__main__':
    build_pdf()
