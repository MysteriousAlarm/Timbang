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
