const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment, assertSucceeds, assertFails,
} = require('@firebase/rules-unit-testing');
const { ref, uploadBytes, getBytes, deleteObject } = require('firebase/storage');

let env;
const small = new Uint8Array(1024);
const big = new Uint8Array(1024 * 1024 + 1);

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-timbang',
    storage: { rules: fs.readFileSync(path.join(__dirname, '../../storage.rules'), 'utf8') },
  });
});
afterAll(async () => env.cleanup());
beforeEach(async () => env.clearStorage());

const owner = () => env.authenticatedContext('farmer1').storage();
const other = () => env.authenticatedContext('other1').storage();
const anon = () => env.unauthenticatedContext().storage();
const P = 'listings/farmer1/l1/photo.jpg';

describe('storage: listing photos', () => {
  test('owner can upload a small jpeg', async () => {
    await assertSucceeds(uploadBytes(ref(owner(), P), small, { contentType: 'image/jpeg' }));
  });
  test.each(['image/png', 'image/webp'])('owner can upload %s', async (ct) => {
    await assertSucceeds(uploadBytes(ref(owner(), P), small, { contentType: ct }));
  });
  test('rejects files of 1 MB or more', async () => {
    await assertFails(uploadBytes(ref(owner(), P), big, { contentType: 'image/jpeg' }));
  });
  test.each(['application/pdf', 'text/html', 'image/svg+xml'])('rejects %s', async (ct) => {
    await assertFails(uploadBytes(ref(owner(), P), small, { contentType: ct }));
  });
  test('cannot upload into another user folder', async () => {
    await assertFails(uploadBytes(ref(other(), P), small, { contentType: 'image/jpeg' }));
  });
  test('unauthenticated cannot upload or read', async () => {
    await assertFails(uploadBytes(ref(anon(), P), small, { contentType: 'image/jpeg' }));
    await assertFails(getBytes(ref(anon(), P)));
  });
  test('signed-in user can read; only owner can delete', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), P), small, { contentType: 'image/jpeg' });
    });
    await assertSucceeds(getBytes(ref(other(), P)));
    await assertFails(deleteObject(ref(other(), P)));
    await assertSucceeds(deleteObject(ref(owner(), P)));
  });
  test('any other path is denied', async () => {
    await assertFails(uploadBytes(ref(owner(), 'avatars/farmer1.jpg'), small, { contentType: 'image/jpeg' }));
  });
});
