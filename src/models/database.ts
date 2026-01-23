import { drizzle } from 'drizzle-orm/better-sqlite3';
import Database from 'better-sqlite3';
import path from 'path';

// Determine database path based on environment
const getDatabasePath = (): string => {
  // Use environment variable if set
  if (process.env.DATABASE_PATH) {
    return process.env.DATABASE_PATH;
  }
  
  // In production, prefer /datadrive if it exists
  if (process.env.NODE_ENV === 'production') {
    const prodPath = '/datadrive/vid2story/data/sqlite.db';
    return prodPath;
  }
  
  // Default to current directory for development
  return 'sqlite.db';
};

const dbPath = getDatabasePath();

// Initialize SQLite database
export const sqlite = new Database(dbPath);

// Create Drizzle instance
export const db = drizzle(sqlite);
