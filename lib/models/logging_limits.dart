/// Sanity caps for a single meal or exercise entry. These guard against
/// fat-finger input and wildly wrong AI estimates — they're roughly a day's
/// worth, not a strict medical limit.
const double kMaxSingleEntryCalories = 6900;
const double kMaxSingleMealProtein = 690;
