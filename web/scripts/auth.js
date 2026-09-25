// Full-fledged User Authentication & Session Vault for QuizPro
const VAULT_KEY = 'quizpro_accounts_vault_v3';
const SESSION_KEY = 'quizpro_active_session_v3';

async function hashPassword(plainText) {
  if (!plainText) return '';
  const encoder = new TextEncoder();
  const data = encoder.encode(plainText);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

class AuthService {
  constructor() {
    this.init();
  }

  init() {
    if (!localStorage.getItem(VAULT_KEY)) {
      localStorage.setItem(VAULT_KEY, JSON.stringify([]));
    }
  }

  getUsers() {
    try {
      return JSON.parse(localStorage.getItem(VAULT_KEY) || '[]');
    } catch {
      return [];
    }
  }

  getActiveUser() {
    try {
      const session = localStorage.getItem(SESSION_KEY);
      if (!session) return null;
      return JSON.parse(session);
    } catch {
      return null;
    }
  }

  isAuthenticated() {
    return this.getActiveUser() !== null;
  }

  async register({ name, email, password, avatarEmoji = '🎓', targetExam = 'General' }) {
    const cleanEmail = email.trim().toLowerCase();
    const cleanName = name.trim();

    if (!cleanName) throw new Error('Please enter your full name.');
    if (!cleanEmail || !cleanEmail.includes('@')) throw new Error('Please enter a valid email address.');
    if (!password || password.length < 6) throw new Error('Password must be at least 6 characters.');

    const users = this.getUsers();
    if (users.some(u => u.email === cleanEmail)) {
      throw new Error('An account with this email already exists. Please log in.');
    }

    const passwordHash = await hashPassword(password);
    const newUser = {
      id: 'usr_' + Date.now(),
      name: cleanName,
      email: cleanEmail,
      passwordHash,
      avatarEmoji: avatarEmoji || '🎓',
      targetExam: targetExam || 'Certifications',
      createdAt: new Date().toISOString()
    };

    users.push(newUser);
    localStorage.setItem(VAULT_KEY, JSON.stringify(users));

    // Start session
    this.setSession(newUser);
    return newUser;
  }

  async login({ email, password }) {
    const cleanEmail = email.trim().toLowerCase();
    const users = this.getUsers();
    const user = users.find(u => u.email === cleanEmail);

    if (!user) {
      throw new Error('No account found with this email. Please check your spelling or sign up.');
    }

    const inputHash = await hashPassword(password);
    if (user.passwordHash !== inputHash) {
      throw new Error('Incorrect password. Please try again.');
    }

    this.setSession(user);
    return user;
  }

  loginAsGuest() {
    const guestUser = {
      id: 'guest_' + Date.now(),
      name: 'Guest Scholar',
      email: 'guest@quizpro.local',
      avatarEmoji: '⚡',
      targetExam: 'Practice Session',
      isGuest: true,
      createdAt: new Date().toISOString()
    };
    this.setSession(guestUser);
    return guestUser;
  }

  setSession(user) {
    const safeUser = {
      id: user.id,
      name: user.name,
      email: user.email,
      avatarEmoji: user.avatarEmoji || '🎓',
      targetExam: user.targetExam || 'General',
      isGuest: !!user.isGuest,
      loggedInAt: new Date().toISOString()
    };
    localStorage.setItem(SESSION_KEY, JSON.stringify(safeUser));
    return safeUser;
  }

  logout() {
    localStorage.removeItem(SESSION_KEY);
  }

  updateProfile({ name, avatarEmoji, targetExam }) {
    const currentUser = this.getActiveUser();
    if (!currentUser) return null;

    currentUser.name = name ? name.trim() : currentUser.name;
    currentUser.avatarEmoji = avatarEmoji || currentUser.avatarEmoji;
    currentUser.targetExam = targetExam || currentUser.targetExam;

    this.setSession(currentUser);

    // If not guest, update in vault as well
    if (!currentUser.isGuest) {
      const users = this.getUsers();
      const idx = users.findIndex(u => u.id === currentUser.id);
      if (idx >= 0) {
        users[idx].name = currentUser.name;
        users[idx].avatarEmoji = currentUser.avatarEmoji;
        users[idx].targetExam = currentUser.targetExam;
        localStorage.setItem(VAULT_KEY, JSON.stringify(users));
      }
    }

    return currentUser;
  }
}

export const Auth = new AuthService();
