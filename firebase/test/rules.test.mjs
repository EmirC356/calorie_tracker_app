// Firestore security-rules tests, run against the emulator:
//   cd firebase && npm install && npm run test:rules
// Verifies the core Squad guarantees — above all, that a NON-MEMBER cannot read
// a squad's docs. No live Firebase is touched (emulator only).
import { readFileSync } from 'fs';
import assert from 'assert';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, arrayUnion, arrayRemove, setLogLevel,
  collection, query, where, getDocs, addDoc, writeBatch, increment,
} from 'firebase/firestore';

setLogLevel('error');

const week = 7 * 24 * 60 * 60 * 1000;
const testEnv = await initializeTestEnvironment({
  projectId: 'demo-squad',
  firestore: { rules: readFileSync('firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
});

// Seed: squad s1 owned by 'owner' with member 'm1'.
await testEnv.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'squads/s1'), {
    name: 'S', ownerUid: 'owner', memberUids: ['owner', 'm1'],
    inviteCode: '123456', inviteCodeExpiresAt: new Date(Date.now() + week), createdAt: new Date(),
  });
  await setDoc(doc(db, 'squadCodes/123456'), { squadId: 's1', expiresAt: new Date(Date.now() + week) });

  // Phase 6: a squad-visible goal occurrence for m1 (readerUids = s1 members),
  // and a pending suggestion from owner -> m1.
  await setDoc(doc(db, 'users/m1/goalsVisible/g1_2026-06-09'), {
    ownerUid: 'm1', goalTitle: 'Read 30 min', category: 'Personal', colorArgb: 123,
    priority: 'high', date: '2026-06-09', status: 'open', period: null,
    metricSummary: null, squadIds: ['s1'], readerUids: ['owner', 'm1'],
  });
  await setDoc(doc(db, 'squads/s1/suggestions/sug1'), {
    fromUid: 'owner', fromName: 'O', toUid: 'm1', payloadJson: '{}',
    createdAt: new Date(), expiresAt: new Date(Date.now() + week), status: 'pending',
  });
});

const owner = testEnv.authenticatedContext('owner').firestore();
const member = testEnv.authenticatedContext('m1').firestore();
const outsider = testEnv.authenticatedContext('out').firestore();
const outsider2 = testEnv.authenticatedContext('out2').firestore();

let n = 0;
const check = async (label, p) => { await p; n++; console.log(`  ✓ ${label}`); };

// The headline requirement: a non-member cannot read squad docs.
await check('non-member CANNOT read squad', assertFails(getDoc(doc(outsider, 'squads/s1'))));
await check('member CAN read squad', assertSucceeds(getDoc(doc(member, 'squads/s1'))));

// "My squads" list query: allowed only with the array-contains self filter.
await check('member CAN list own squads (array-contains self)',
  assertSucceeds(getDocs(query(collection(member, 'squads'), where('memberUids', 'array-contains', 'm1')))));
await check('CANNOT list all squads unfiltered',
  assertFails(getDocs(collection(outsider, 'squads'))));
await check('anyone signed-in can resolve a code lookup', assertSucceeds(getDoc(doc(outsider, 'squadCodes/123456'))));

// Self-join: an outsider may add ONLY themselves.
await check('outsider self-joins (adds self)', assertSucceeds(updateDoc(doc(outsider, 'squads/s1'), { memberUids: arrayUnion('out') })));
await check('outsider CANNOT add someone else', assertFails(updateDoc(doc(outsider2, 'squads/s1'), { memberUids: arrayUnion('victim') })));

// Entries: self-only writes.
await check('member writes OWN entry', assertSucceeds(setDoc(doc(member, 'squads/s1/days/2026-06-09/entries/m1'), { status: 'hit', updatedAt: new Date() })));
await check("member CANNOT write another's entry", assertFails(setDoc(doc(member, 'squads/s1/days/2026-06-09/entries/owner'), { status: 'hit' })));

// Member doc: sharingLevel enum enforced.
await check('valid sharingLevel accepted', assertSucceeds(setDoc(doc(member, 'squads/s1/members/m1'), { sharingLevel: 'totals', goal: {} })));
await check('invalid sharingLevel rejected', assertFails(setDoc(doc(member, 'squads/s1/members/m1'), { sharingLevel: 'everything', goal: {} })));
await check('member can update OWN goal (merge)', assertSucceeds(setDoc(doc(member, 'squads/s1/members/m1'), { goal: { calorieMode: 'cap', calorieTarget: 2000 } }, { merge: true })));
await check("member CANNOT edit another's member doc", assertFails(setDoc(doc(member, 'squads/s1/members/owner'), { sharingLevel: 'full', goal: {} })));

// Pause object bounded: ≤21-day window and ≤60-day yearly tally (merge onto the
// existing member doc, which already carries a valid sharingLevel).
await check('valid pause accepted',
  assertSucceeds(setDoc(doc(member, 'squads/s1/members/m1'), { pause: { active: true, until: '2026-06-20', windowDays: 5, daysUsedThisYear: 10 } }, { merge: true })));
await check('pause window of exactly 21 days accepted',
  assertSucceeds(setDoc(doc(member, 'squads/s1/members/m1'), { pause: { active: true, until: '2026-06-30', windowDays: 21, daysUsedThisYear: 21 } }, { merge: true })));
await check('pause window over 21 days rejected',
  assertFails(setDoc(doc(member, 'squads/s1/members/m1'), { pause: { active: true, until: '2026-08-01', windowDays: 22, daysUsedThisYear: 22 } }, { merge: true })));
await check('pause exceeding the 60-day yearly cap rejected',
  assertFails(setDoc(doc(member, 'squads/s1/members/m1'), { pause: { active: true, until: '2026-06-20', windowDays: 5, daysUsedThisYear: 61 } }, { merge: true })));

// Reactions: nudge another member yes, yourself no.
const reactions = 'squads/s1/days/2026-06-09/reactions';
await check('member can nudge another member',
  assertSucceeds(addDoc(collection(member, reactions), { fromUid: 'm1', toUid: 'owner', emoji: 'fire', fromName: 'M' })));
await check('member CANNOT nudge themselves',
  assertFails(addDoc(collection(member, reactions), { fromUid: 'm1', toUid: 'm1', emoji: 'fire', fromName: 'M' })));

// Leave: a non-owner removes only themselves ('out' joined earlier).
await check('non-owner can LEAVE (remove self)', assertSucceeds(updateDoc(doc(outsider, 'squads/s1'), { memberUids: arrayRemove('out') })));

// ── Phase 6: goalsVisible ─────────────────────────────────────────────────────
const gv = 'users/m1/goalsVisible/g1_2026-06-09';
await check('squadmate CAN read my visible goal (in readerUids)', assertSucceeds(getDoc(doc(owner, gv))));
await check('owner of the doc CAN read it', assertSucceeds(getDoc(doc(member, gv))));
await check('non-squadmate CANNOT read my visible goal', assertFails(getDoc(doc(outsider, gv))));
await check('a squadmate CANNOT write my goalsVisible doc', assertFails(setDoc(doc(owner, gv), { ownerUid: 'm1', readerUids: ['owner'] })));

// ── Phase 6: suggestions ──────────────────────────────────────────────────────
const sugCol = 'squads/s1/suggestions';
await check('member CANNOT create a suggestion with someone else as fromUid',
  assertFails(setDoc(doc(member, `${sugCol}/forge`), { fromUid: 'owner', toUid: 'owner', payloadJson: '{}', status: 'pending' })));
await check('member CAN suggest a goal to another member',
  assertSucceeds(setDoc(doc(member, `${sugCol}/sug_m1`), { fromUid: 'm1', toUid: 'owner', payloadJson: '{}', status: 'pending' })));
await check('CANNOT create a suggestion to a non-member',
  assertFails(setDoc(doc(member, `${sugCol}/sug_x`), { fromUid: 'm1', toUid: 'stranger', payloadJson: '{}', status: 'pending' })));
await check('sender CAN read a suggestion', assertSucceeds(getDoc(doc(owner, `${sugCol}/sug1`))));
await check('recipient CAN read a suggestion', assertSucceeds(getDoc(doc(member, `${sugCol}/sug1`))));
await check('outsider CANNOT read a suggestion', assertFails(getDoc(doc(outsider, `${sugCol}/sug1`))));
await check('non-recipient CANNOT update a suggestion', assertFails(updateDoc(doc(owner, `${sugCol}/sug1`), { status: 'accepted' })));
await check('recipient CAN accept a suggestion (pending -> accepted)',
  assertSucceeds(updateDoc(doc(member, `${sugCol}/sug1`), { status: 'accepted' })));

// ── Phase 8: notification queue (todaysGoalsBrief + pendingReminders) ─────────
await check('owner CAN write own morning brief',
  assertSucceeds(setDoc(doc(member, 'users/m1/todaysGoalsBrief/2026-06-09'), { goalsCount: 2, items: [] })));
await check("outsider CANNOT read another's morning brief",
  assertFails(getDoc(doc(outsider, 'users/m1/todaysGoalsBrief/2026-06-09'))));
await check('owner CAN write own pending reminder',
  assertSucceeds(setDoc(doc(member, 'users/m1/pendingReminders/g1_2026-06-09'), { fireAt: new Date().toISOString(), title: 'Read' })));
await check("outsider CANNOT read another's pending reminders",
  assertFails(getDoc(doc(outsider, 'users/m1/pendingReminders/g1_2026-06-09'))));

// ── Social sprint: retro / activity feed / mass-nudge ─────────────────────────
await check('owner CAN read own weekly retro',
  assertSucceeds(getDoc(doc(member, 'users/m1/weeklyRetros/2026-W24'))));
await check('client CANNOT write a weekly retro (functions only)',
  assertFails(setDoc(doc(member, 'users/m1/weeklyRetros/2026-W24'), { payload: {} })));
await check('member CAN read the activity feed',
  assertSucceeds(getDoc(doc(member, 'squads/s1/activity/a1'))));
await check('client CANNOT write the activity feed (functions only)',
  assertFails(setDoc(doc(member, 'squads/s1/activity/a2'), { type: 'x' })));
await check('member CAN add self to a ghost mass-nudge',
  assertSucceeds(setDoc(doc(member, 'squads/s1/ghostChecks/2026-06-15/aggregateNudges/owner'), { nudgerUids: ['m1'], count: 1 })));
await check('member CANNOT nudge without including self',
  assertFails(setDoc(doc(member, 'squads/s1/ghostChecks/2026-06-15/aggregateNudges/owner'), { nudgerUids: ['x'], count: 1 })));

// ── Weekly intentions (self-write, member-read, ≤80, immutable after grading) ──
const intMembers = 'squads/s1/intentions/2026-W24/members';
await check('member CAN declare an intention',
  assertSucceeds(setDoc(doc(member, `${intMembers}/m1`), { uid: 'm1', text: 'Gym 3x', gradedStatus: 'unset' })));
await check('member CANNOT declare for someone else',
  assertFails(setDoc(doc(member, `${intMembers}/owner`), { uid: 'owner', text: 'x', gradedStatus: 'unset' })));
await check('intention over 80 chars rejected',
  assertFails(setDoc(doc(member, `${intMembers}/m1`), { text: 'x'.repeat(81) }, { merge: true })));
await check('member CAN self-grade (unset -> hit)',
  assertSucceeds(setDoc(doc(member, `${intMembers}/m1`), { gradedStatus: 'hit' }, { merge: true })));
await check('intention is immutable after grading',
  assertFails(setDoc(doc(member, `${intMembers}/m1`), { text: 'changed' }, { merge: true })));

// ── Group goals (owner create/delete; members self-increment only) ────────────
await check('owner CAN create a group goal',
  assertSucceeds(setDoc(doc(owner, 'squads/s1/groupGoals/gg1'),
    { title: '50 workouts', metric: 'exerciseSessionsTotal', target: 50, createdBy: 'owner', contributions: {}, currentValue: 0 })));
await check('non-owner CANNOT create a group goal',
  assertFails(setDoc(doc(member, 'squads/s1/groupGoals/gg2'),
    { title: 'x', metric: 'mealsLoggedTotal', target: 1, createdBy: 'm1', contributions: {}, currentValue: 0 })));
await check('member CAN read group goals',
  assertSucceeds(getDoc(doc(member, 'squads/s1/groupGoals/gg1'))));
await check('member CAN increment OWN contribution',
  assertSucceeds(updateDoc(doc(member, 'squads/s1/groupGoals/gg1'), { 'contributions.m1': 5, currentValue: 5 })));
await check("member CANNOT change another's contribution",
  assertFails(updateDoc(doc(member, 'squads/s1/groupGoals/gg1'), { 'contributions.owner': 9 })));
await check('member CANNOT edit the goal definition',
  assertFails(updateDoc(doc(member, 'squads/s1/groupGoals/gg1'), { title: 'hacked' })));

// ── Per-day comments (self-from, member-to, ≤200, ≤5/pair/day via counter) ─────
const cday = 'squads/s1/days/2026-06-09';
function commentBatch(db, counterId, commentId, data) {
  const b = writeBatch(db);
  b.set(doc(db, `${cday}/commentCounters/${counterId}`), { count: increment(1), ...data.counter }, { merge: true });
  b.set(doc(db, `${cday}/comments/${commentId}`), data.comment);
  return b;
}
await check('member CAN comment on a squadmate',
  assertSucceeds(commentBatch(member, 'm1_owner', 'c1',
    { counter: { fromUid: 'm1', toUid: 'owner' }, comment: { fromUid: 'm1', fromName: 'M', toUid: 'owner', text: 'nice work', createdAt: new Date() } }).commit()));
await check('CANNOT comment to a non-member',
  assertFails(commentBatch(member, 'm1_out', 'c2',
    { counter: {}, comment: { fromUid: 'm1', fromName: 'M', toUid: 'out', text: 'x', createdAt: new Date() } }).commit()));
await check('CANNOT forge fromUid',
  assertFails(commentBatch(member, 'owner_owner', 'c3',
    { counter: {}, comment: { fromUid: 'owner', fromName: 'M', toUid: 'owner', text: 'x', createdAt: new Date() } }).commit()));
await check('comment over 200 chars rejected',
  assertFails(commentBatch(member, 'm1_owner', 'c4',
    { counter: {}, comment: { fromUid: 'm1', fromName: 'M', toUid: 'owner', text: 'x'.repeat(201), createdAt: new Date() } }).commit()));
await testEnv.withSecurityRulesDisabled(async (ctx) => {
  await setDoc(doc(ctx.firestore(), `${cday}/commentCounters/m1_owner`), { count: 5 });
});
await check('6th comment to the same pair rejected',
  assertFails(commentBatch(member, 'm1_owner', 'c5',
    { counter: {}, comment: { fromUid: 'm1', fromName: 'M', toUid: 'owner', text: 'one too many', createdAt: new Date() } }).commit()));
await check('author CAN edit own comment',
  assertSucceeds(updateDoc(doc(member, `${cday}/comments/c1`), { text: 'edited', editedAt: new Date() })));
await check('non-author CANNOT edit a comment',
  assertFails(updateDoc(doc(owner, `${cday}/comments/c1`), { text: 'hax' })));

// ── notificationPrefs/master (per-user push switches) ─────────────────────────
await check('owner CAN write own notification prefs',
  assertSucceeds(setDoc(doc(member, 'users/m1/notificationPrefs/master'), { retros: false, quietHoursStart: '22:00' })));
await check("outsider CANNOT read another's notification prefs",
  assertFails(getDoc(doc(outsider, 'users/m1/notificationPrefs/master'))));

await testEnv.cleanup();
console.log(`\nALL ${n} RULES TESTS PASSED`);
assert(n === 62);
