// Supabase Cloud Database Client & Synchronization Engine for QuizPro
const SUPABASE_CONFIG_KEY = 'quizpro_supabase_config_v3';

// Default Supabase project configuration (can be configured in Settings)
const DEFAULT_CONFIG = {
  url: 'https://kafhbffonnzgoagriwhf.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImthZmhiZmZvbm56Z29hZ3Jpd2hmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzNDM0MzUsImV4cCI6MjEwNTkxOTQzNX0.Yc4wpLG_oLyj6V-UCHOPtyX_rRs_LpZ2JeiW_AFLg3c',
  autoSync: true
};

class SupabaseService {
  constructor() {
    this.client = null;
    this.init();
  }

  init() {
    const config = this.getConfig();
    if (config.url && config.anonKey) {
      this.initClient(config.url, config.anonKey);
    }
  }

  getConfig() {
    try {
      const stored = localStorage.getItem(SUPABASE_CONFIG_KEY);
      return stored ? { ...DEFAULT_CONFIG, ...JSON.parse(stored) } : { ...DEFAULT_CONFIG };
    } catch {
      return { ...DEFAULT_CONFIG };
    }
  }

  saveConfig(newConfig) {
    const current = this.getConfig();
    const merged = { ...current, ...newConfig };
    localStorage.setItem(SUPABASE_CONFIG_KEY, JSON.stringify(merged));
    if (merged.url && merged.anonKey) {
      this.initClient(merged.url, merged.anonKey);
    } else {
      this.client = null;
    }
    return merged;
  }

  initClient(url, anonKey) {
    try {
      if (typeof window.supabase !== 'undefined' && window.supabase.createClient) {
        this.client = window.supabase.createClient(url, anonKey);
      }
    } catch (e) {
      console.warn('Supabase initialization deferred:', e);
      this.client = null;
    }
  }

  isConfigured() {
    const cfg = this.getConfig();
    return !!(cfg.url && cfg.anonKey && this.client);
  }

  async testConnection() {
    const cfg = this.getConfig();
    if (!cfg.url || !cfg.anonKey) {
      throw new Error('Please enter both Supabase Project URL and Anon Public Key.');
    }

    if (!this.client) {
      this.initClient(cfg.url, cfg.anonKey);
    }

    if (!this.client) {
      throw new Error('Supabase JS SDK is not loaded. Please check your network connection.');
    }

    // Try a ping query on the exams table or database health check
    const { data, error } = await this.client.from('exams').select('id').limit(1);
    if (error) {
      // If table doesn't exist yet, but authentication was valid, report table guidance
      if (error.code === '42P01' || error.code === 'PGRST205') {
        return {
          success: true,
          notice: 'Connected to Supabase! (Note: The "exams" table is not yet created. Run schema.sql in your Supabase SQL Editor).'
        };
      }
      throw new Error(`Supabase Error (${error.code || 'ERR'}): ${error.message}`);
    }

    return { success: true, count: data ? data.length : 0 };
  }

  // --- Cloud Sync: Push Local Exams to Supabase ---
  async syncExamsToCloud(exams) {
    if (!this.isConfigured()) return { synced: 0, skipped: true };

    try {
      const records = exams.map(e => ({
        id: e.id,
        name: e.name,
        category: e.category || 'General',
        provider: e.provider || '',
        description: e.description || '',
        default_duration: e.defaultDuration || 30,
        passing_percentage: e.passingPercentage || 70,
        questions: e.questions || [],
        updated_at: new Date().toISOString()
      }));

      if (records.length === 0) return { synced: 0 };

      const { data, error } = await this.client
        .from('exams')
        .upsert(records, { onConflict: 'id' });

      if (error) throw error;
      return { synced: records.length, success: true };
    } catch (err) {
      console.error('Supabase exams push failed:', err);
      throw err;
    }
  }

  // --- Cloud Sync: Pull Remote Exams from Supabase ---
  async pullExamsFromCloud() {
    if (!this.isConfigured()) return [];

    try {
      const { data, error } = await this.client
        .from('exams')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;

      return (data || []).map(row => ({
        id: row.id,
        name: row.name,
        category: row.category,
        provider: row.provider,
        description: row.description,
        defaultDuration: row.default_duration,
        passingPercentage: row.passing_percentage,
        questions: Array.isArray(row.questions) ? row.questions : [],
        createdAt: row.created_at || new Date().toISOString()
      }));
    } catch (err) {
      console.error('Supabase exams pull failed:', err);
      throw err;
    }
  }

  // --- Cloud Sync: Push Performance History ---
  async syncPerformanceToCloud(perf) {
    if (!this.isConfigured()) return null;

    try {
      const record = {
        id: perf.id || 'perf_' + Date.now(),
        exam_id: perf.examId,
        student_id: perf.studentId,
        score: perf.score,
        total_questions: perf.totalQuestions,
        passed: !!perf.passed,
        time_spent_seconds: perf.timeSpentSeconds || 0,
        mode: perf.mode || 'exam',
        answers: perf.answers || [],
        created_at: perf.date || new Date().toISOString()
      };

      const { data, error } = await this.client
        .from('performances')
        .upsert([record], { onConflict: 'id' });

      if (error) throw error;
      return record;
    } catch (err) {
      console.error('Supabase performance push failed:', err);
      return null;
    }
  }

  // --- Cloud Sync: Pull Performance History ---
  async pullPerformancesFromCloud(studentId) {
    if (!this.isConfigured()) return [];

    try {
      let query = this.client.from('performances').select('*');
      if (studentId) {
        query = query.eq('student_id', studentId);
      }
      query = query.order('created_at', { ascending: false });

      const { data, error } = await query;
      if (error) throw error;

      return (data || []).map(row => ({
        id: row.id,
        examId: row.exam_id,
        studentId: row.student_id,
        score: row.score,
        totalQuestions: row.total_questions,
        passed: row.passed,
        timeSpentSeconds: row.time_spent_seconds,
        mode: row.mode,
        answers: row.answers || [],
        date: row.created_at
      }));
    } catch (err) {
      console.error('Supabase performances pull failed:', err);
      return [];
    }
  }
}

export const Supabase = new SupabaseService();
