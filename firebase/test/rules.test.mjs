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
  doc, getDoc, setDoc, updateDoc, arrayUnion, setLogLevel,
  collection, query, where, getDocs,
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
});

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

await testEnv.cleanup();
console.log(`\nALL ${n} RULES TESTS PASSED`);
assert(n === 11);
