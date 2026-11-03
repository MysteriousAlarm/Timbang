/**
 * All tunable numbers and allowed enums for TIMBANG Cloud Functions live here.
 * Keep in sync with app/lib/core/config/app_config.dart and firestore.rules.
 */
export const ROLES = ['farmer', 'buyer', 'reporter', 'admin'] as const;
export type Role = (typeof ROLES)[number];

/** Roles a user may pick for themselves at signup. */
export const SELF_SIGNUP_ROLES: readonly Role[] = ['farmer', 'buyer'];

export const MUNICIPALITIES = [
  'Alfonso Castañeda',
  'Ambaguio',
  'Aritao',
  'Bagabag',
  'Bambang',
  'Bayombong',
  'Diadi',
  'Dupax del Norte',
  'Dupax del Sur',
  'Kasibu',
  'Kayapa',
  'Quezon',
  'Santa Fe',
  'Solano',
  'Villaverde',
] as const;

export const REGION = 'asia-southeast1';

// Price confidence (Section 8). Used from Step 3.
export const PRICE_WINDOW_HOURS = 24;
export const OUTLIER_THRESHOLD = 0.3;
export const AGREEMENT_THRESHOLD = 0.15;
export const TREND_FLAT_BAND = 0.03;

// Catalog (Step 2). Lists are admin-managed data, not code: these are only the shapes.
export const UNITS = ['kg', 'bundle', 'piece'] as const;
export const MARKET_TYPES = ['public_market', 'trading_post', 'farmgate_area'] as const;
export const CATALOG_ID_PATTERN = /^[a-z0-9][a-z0-9-]{1,48}$/;
export const CATALOG_MAX_ITEMS_PER_CALL = 500;

// Price reports (Step 3).
export const SOURCES = ['official', 'reporter', 'community'] as const;
export type Source = (typeof SOURCES)[number];
export const PRICE_MIN = 0.01;
export const PRICE_MAX = 100000;
/** Max reports one user may submit per rolling hour. */
export const REPORTS_PER_HOUR = 20;
/** Same user + commodity + market may report again only after this many minutes. */
export const DUPLICATE_REPORT_MINUTES = 10;
export const OFFICIAL_IMPORT_MAX_ROWS = 500;

// Listings (Step 5).
export const LISTING_DAYS = 14;
