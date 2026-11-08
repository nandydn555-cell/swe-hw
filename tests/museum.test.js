import test from 'node:test';
import assert from 'node:assert/strict';
import { canManageExhibit, exhibitDraft, hydrateExhibits, hydrateTeachers, hydrateEvents, validateExhibit } from '../src/lib/museum.js';
import { filterExhibits } from '../src/exhibits.js';

test('published/rejected owners can manage their work, but visitors and other users cannot', () => {
  for (const status of ['pending', 'published', 'rejected']) {
    const item = { creator_id: 'alice', status };
    assert.equal(canManageExhibit(item, { id: 'alice' }, false), true);
    assert.equal(canManageExhibit(item, { id: 'bob' }, false), false);
    assert.equal(canManageExhibit(item, null, false), false);
    assert.equal(canManageExhibit(item, { id: 'admin' }, true), true);
  }
  assert.equal(canManageExhibit({ reference_only: true }, { id: 'admin' }, true), false);
});

test('empty server results stay empty after deletion, even with a local archive', () => {
  assert.deepEqual(hydrateExhibits([], [{ title: 'Deleted' }]), []);
  assert.deepEqual(hydrateEvents([], [{ title: 'Deleted' }]), []);
  assert.deepEqual(hydrateTeachers([]), []);
});

test('editing server arrays and optional null fields produces a usable form', () => {
  const draft = exhibitDraft({ technology_stack: ['React', 'Python'], courses: ['DB', 'Web'], bio: null });
  assert.equal(draft.technology_stack, 'React, Python');
  assert.equal(draft.courses, 'DB, Web');
  assert.equal(draft.bio, '');
});

test('persisted archive authors and metadata survive a title change', () => {
  const [item] = hydrateExhibits([{ title: 'New title', creator_name: 'Original author', archive_details: { topics: ['AI'] }, profiles: { display_name: 'Importer' } }]);
  assert.equal(item.creator, 'Original author');
  assert.deepEqual(item.topics, ['AI']);
});

test('drafts stay out of public search, and year/category/technology filters combine', () => {
  const items = [{ title: 'A', status: 'published', category: 'Web', year_created: 2026, technology_stack: ['React'] }, { title: 'Private', status: 'pending', year_created: 2026 }];
  assert.equal(filterExhibits(items, { query: '2026' }).length, 1);
  assert.equal(filterExhibits(items, { query: 'react', category: 'Web' }).length, 1);
  assert.equal(filterExhibits(items, { query: 'private' }).length, 0);
  assert.equal(filterExhibits(items, { category: 'Other' }).length, 0);
});

test('blank content, invalid years and executable URLs are rejected before upload', () => {
  const valid = { title: 'Museum', description: 'Description', year_created: 2026 };
  assert.doesNotThrow(() => validateExhibit(valid));
  for (const change of [{ title: ' ' }, { description: ' ' }, { year_created: 1 }, { year_created: 2026.5 }, { demo_url: 'javascript:alert(1)' }]) {
    assert.throws(() => validateExhibit({ ...valid, ...change }));
  }
});
