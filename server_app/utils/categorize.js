// Keyword → Category mapping
const CATEGORY_RULES = {
  'Food & Dining': [
    'swiggy', 'zomato', 'dominos', 'pizza', 'kfc', 'mcdonalds', 'mcdonald',
    'burger', 'biryani', 'restaurant', 'cafe', 'hotel', 'food', 'eat',
    'dunzo', 'blinkit', 'zepto', 'instamart', 'chai', 'dhaba',
  ],
  'Transport': [
    'uber', 'ola', 'rapido', 'auto', 'cab', 'taxi', 'metro', 'bus',
    'irctc', 'train', 'flight', 'indigo', 'spicejet', 'petrol', 'diesel',
    'fuel', 'parking', 'toll', 'redbus', 'makemytrip',
  ],
  'Grocery': [
    'bigbasket', 'grofers', 'blinkit', 'jiomart', 'dmart', 'reliance fresh',
    'more supermarket', 'grocery', 'vegetables', 'fruits', 'milk', 'dairy',
    'supermarket', 'kirana',
  ],
  'Bills': [
    'airtel', 'jio', 'vi ', 'vodafone', 'bsnl', 'recharge', 'electricity',
    'bescom', 'tneb', 'msedcl', 'water', 'gas', 'cylinder', 'ott',
    'netflix', 'hotstar', 'amazon prime', 'spotify', 'broadband', 'wifi',
    'insurance', 'lic', 'postpaid',
  ],
  'Health': [
    'pharmacy', 'medical', 'hospital', 'clinic', 'doctor', 'apollo',
    'netmeds', 'pharmeasy', '1mg', 'medplus', 'diagnostics', 'lab',
    'medicine', 'chemist',
  ],
  'Shopping': [
    'amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'meesho', 'snapdeal',
    'reliance digital', 'croma', 'vijay sales', 'shopping', 'mall', 'store',
    'fashion', 'clothes', 'shoes',
  ],
  'Transfer': [
    'transfer', 'sent to', 'paid to', 'wallet', 'paytm wallet',
    'phonepe wallet', 'gpay', 'neft', 'imps', 'rtgs',
  ],
};

/**
 * Auto-detect category from payee name or notification text
 * @param {string} text - payee name or full notification text
 * @returns {string} category
 */
const detectCategory = (text = '') => {
  const lower = text.toLowerCase();
  for (const [category, keywords] of Object.entries(CATEGORY_RULES)) {
    if (keywords.some(kw => lower.includes(kw))) {
      return category;
    }
  }
  return 'Other';
};

/**
 * Parse UPI notification text into structured data
 * @param {string} text - notification title + body combined
 * @param {string} packageName - UPI app package name
 * @returns {object|null}
 */
const parseNotification = (text = '', packageName = '') => {
  // Strip balance details to avoid parsing balance as the transaction amount
  const cleanText = text.replace(/(?:bal|balance|avail\s+bal|available\s+bal|available\s+balance|avbl\s+bal|ledger\s+bal|net\s+bal|effective\s+bal)[:\s#]*(?:₹|Rs\.?|INR)?\s*[\d,]+(?:\.\d{1,2})?/gi, '');

  // Amount patterns: ₹500, Rs.500, Rs 500, INR 500
  const amountMatch = cleanText.match(/(?:₹|Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)/i);
  if (!amountMatch) return null;

  const amount = parseFloat(amountMatch[1].replace(/,/g, ''));
  if (!amount || amount <= 0) return null;

  // Payee patterns
  const payeeMatch = cleanText.match(
    /(?:paid to|sent to|payment to|debit to|to\s+vpa|spent at|spent on|transfer to|info[:\s]+)\s+([A-Za-z0-9@.\-_\s]+?)(?:\s+on|\s+via|\s+ref|\s+upi|\s+linked|$)/i
  );
  const payee = payeeMatch?.[1]?.trim() || 'Unknown';

  // UPI Ref / transaction ID
  const refMatch = cleanText.match(/(?:ref|upi ref|txn|transaction id)(?:\s+no\.?)?[:\s#]+([A-Z0-9]+)/i);
  const upiRef = refMatch?.[1] || null;

  // Map package name to app label
  const APP_MAP = {
    'com.google.android.apps.nbu.paisa.user': 'GPay',
    'com.phonepe.app':                        'PhonePe',
    'net.one97.paytm':                        'Paytm',
    'in.org.npci.upiapp':                     'BHIM',
    'in.amazon.mShop.android.shopping':       'AmazonPay',
  };

  return {
    amount,
    payee,
    upiRef,
    upiApp:   APP_MAP[packageName] || 'Other',
    category: detectCategory(payee + ' ' + cleanText),
    date:     new Date(),
  };
};

module.exports = { detectCategory, parseNotification };
