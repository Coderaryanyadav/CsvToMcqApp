-- ====================================================================
-- QuizPro Supabase Cloud Database Initial Migration
-- ====================================================================

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Examination Catalog Table
CREATE TABLE IF NOT EXISTS public.exams (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT DEFAULT 'General',
    provider TEXT DEFAULT '',
    description TEXT DEFAULT '',
    default_duration INTEGER DEFAULT 30,
    passing_percentage INTEGER DEFAULT 70,
    questions JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW())
);

CREATE INDEX IF NOT EXISTS idx_exams_category ON public.exams (category);
CREATE INDEX IF NOT EXISTS idx_exams_created_at ON public.exams (created_at DESC);

-- 3. Student Profile Table
CREATE TABLE IF NOT EXISTS public.students (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT,
    avatar_emoji TEXT DEFAULT '🎓',
    target_exam TEXT DEFAULT 'General',
    is_guest BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW())
);

-- 4. Test Performances & Attempt History Table
CREATE TABLE IF NOT EXISTS public.performances (
    id TEXT PRIMARY KEY,
    exam_id TEXT NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL,
    score INTEGER NOT NULL,
    total_questions INTEGER NOT NULL,
    passed BOOLEAN NOT NULL,
    time_spent_seconds INTEGER DEFAULT 0,
    mode TEXT DEFAULT 'exam',
    answers JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW())
);

CREATE INDEX IF NOT EXISTS idx_performances_student ON public.performances (student_id);
CREATE INDEX IF NOT EXISTS idx_performances_exam ON public.performances (exam_id);
CREATE INDEX IF NOT EXISTS idx_performances_created ON public.performances (created_at DESC);

-- 5. Student Bookmarks Table
CREATE TABLE IF NOT EXISTS public.bookmarks (
    student_id TEXT NOT NULL,
    question_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()),
    PRIMARY KEY (student_id, question_id)
);

-- 6. Study Streaks Table
CREATE TABLE IF NOT EXISTS public.streaks (
    student_id TEXT PRIMARY KEY,
    current_streak INTEGER DEFAULT 0,
    last_active_date TEXT,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW())
);

-- 7. Row Level Security (RLS) Policies
ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.performances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.streaks ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow public read access to exams') THEN
        CREATE POLICY "Allow public read access to exams" ON public.exams FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow public insert/update to exams') THEN
        CREATE POLICY "Allow public insert/update to exams" ON public.exams FOR ALL USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow public all access to students') THEN
        CREATE POLICY "Allow public all access to students" ON public.students FOR ALL USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow public all access to performances') THEN
        CREATE POLICY "Allow public all access to performances" ON public.performances FOR ALL USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow public all access to bookmarks') THEN
        CREATE POLICY "Allow public all access to bookmarks" ON public.bookmarks FOR ALL USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow public all access to streaks') THEN
        CREATE POLICY "Allow public all access to streaks" ON public.streaks FOR ALL USING (true);
    END IF;
END $$;
