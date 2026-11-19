// Tests des règles Firestore de PartyBox.
// Prérequis : émulateur Firestore lancé (firebase emulators:start) sur 127.0.0.1:8080.
// Lancer : cd firestore-tests && npm install && npm test
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  arrayUnion,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
  addDoc,
} from 'firebase/firestore';

const HOUR = 3600 * 1000;
const inHours = (h) => Timestamp.fromMillis(Date.now() + h * HOUR);

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-partybox-rules',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

// ---------- Helpers ----------
const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

/** Lobby "Soirée" : alice (chef) + bob, mot de passe "secret". */
function baseLobby(overrides = {}) {
  return {
    lobbyName: 'Soirée',
    nameKey: 'soir%C3%A9e',
    password: 'secret',
    status: 'waiting',
    host: 'Alice',
    hostUid: 'alice',
    members: { alice: 'Alice', bob: 'Bob' },
    gameMode: 'Action ou Vérité',
    players: [
      { name: 'Alice', gender: 'F' },
      { name: 'Bob', gender: 'H' },
    ],
    createdAt: Timestamp.now(),
    expireAt: inHours(24),
    ...overrides,
  };
}

async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

async function seedLobby(id = 'L1', overrides = {}) {
  const data = baseLobby(overrides);
  await seed(`lobbies/${id}`, data);
  await seed(`lobbyNames/${data.nameKey}`, { lobbyId: id, expireAt: data.expireAt });
  return data;
}

async function readLobbyRaw(id = 'L1') {
  let data;
  await env.withSecurityRulesDisabled(async (ctx) => {
    data = (await getDoc(doc(ctx.firestore(), `lobbies/${id}`))).data();
  });
  return data;
}

/** Batch de création tel que l'appli le fait. */
function createBatch(uid, { pseudo = 'Alice', name = 'Soirée', key = 'soir%C3%A9e', lobby = {}, nameDoc = {} } = {}) {
  const d = db(uid);
  const lobbyRef = doc(collection(d, 'lobbies'));
  const expireAt = lobby.expireAt ?? inHours(24);
  const b = writeBatch(d);
  b.set(lobbyRef, {
    lobbyName: name,
    nameKey: key,
    password: 'secret',
    status: 'waiting',
    host: pseudo,
    hostUid: uid,
    members: { [uid]: pseudo },
    gameMode: 'Action ou Vérité',
    players: [{ name: pseudo, gender: 'F' }],
    createdAt: serverTimestamp(),
    ...lobby,
    expireAt,
  });
  b.set(doc(d, 'lobbyNames', key), { lobbyId: lobbyRef.id, expireAt, ...nameDoc });
  return b;
}

/** Batch "rejoindre" tel que l'appli le fait. */
function joinBatch(uid, { lobbyId = 'L1', password = 'secret', pseudo = 'Carol', player } = {}) {
  const d = db(uid);
  const b = writeBatch(d);
  b.set(doc(d, `lobbies/${lobbyId}/joins/${uid}`), { password });
  b.update(doc(d, `lobbies/${lobbyId}`), {
    [`members.${uid}`]: pseudo,
    players: arrayUnion(player ?? { name: pseudo, gender: 'F' }),
  });
  return b;
}

// ---------- Tests ----------

describe('non connecté', () => {
  test('tout est refusé', async () => {
    await seedLobby();
    await seed('vipCodes/ABC', { action: 'unlock' });
    const d = anon();
    await assertFails(getDoc(doc(d, 'lobbies/L1')));
    await assertFails(getDoc(doc(d, 'vipCodes/ABC')));
    await assertFails(getDoc(doc(d, 'lobbyNames/soir%C3%A9e')));
    await assertFails(getDocs(collection(d, 'lobbies/L1/messages')));
    await assertFails(createBatch('x').commit());
  });
});

describe('vipCodes', () => {
  test('get autorisé, list et écriture refusés', async () => {
    await seed('vipCodes/ABC', { action: 'unlock' });
    await assertSucceeds(getDoc(doc(db('alice'), 'vipCodes/ABC')));
    await assertFails(getDocs(collection(db('alice'), 'vipCodes')));
    await assertFails(setDoc(doc(db('alice'), 'vipCodes/NEW'), { action: 'unlock' }));
  });
});

describe('lecture des lobbys', () => {
  test('un non-membre ne peut pas lire le lobby (ni son mot de passe)', async () => {
    await seedLobby();
    await assertFails(getDoc(doc(db('eve'), 'lobbies/L1')));
  });

  test('un membre peut lire le lobby', async () => {
    await seedLobby();
    await assertSucceeds(getDoc(doc(db('bob'), 'lobbies/L1')));
  });

  test('lire un lobby inexistant renvoie un doc vide (pas une erreur)', async () => {
    await assertSucceeds(getDoc(doc(db('eve'), 'lobbies/absent')));
  });

  test('impossible de lister les lobbys actifs', async () => {
    await seedLobby();
    await assertFails(getDocs(collection(db('eve'), 'lobbies')));
    await assertFails(getDocs(query(collection(db('eve'), 'lobbies'), where('lobbyName', '==', 'Soirée'))));
    await assertFails(
      getDocs(query(collection(db('eve'), 'lobbies'), where('expireAt', '<', inHours(48)))),
    );
  });

  test('lobbyNames : get autorisé, list refusé', async () => {
    await seedLobby();
    await assertSucceeds(getDoc(doc(db('eve'), 'lobbyNames/soir%C3%A9e')));
    await assertFails(getDocs(collection(db('eve'), 'lobbyNames')));
  });
});

describe('création', () => {
  test('création valide (lobby + nom) acceptée', async () => {
    await assertSucceeds(createBatch('alice').commit());
  });

  test('champ en trop refusé', async () => {
    await assertFails(createBatch('alice', { lobby: { isPremium: true } }).commit());
  });

  test('hostUid d’un autre refusé', async () => {
    await assertFails(createBatch('alice', { lobby: { hostUid: 'bob' } }).commit());
  });

  test('members contenant quelqu’un d’autre refusé', async () => {
    await assertFails(createBatch('alice', { lobby: { members: { alice: 'Alice', bob: 'Bob' } } }).commit());
  });

  test('expireAt dans le passé refusé', async () => {
    await assertFails(createBatch('alice', { lobby: { expireAt: inHours(-1) } }).commit());
  });

  test('expireAt au-delà de 48 h refusé', async () => {
    await assertFails(createBatch('alice', { lobby: { expireAt: inHours(72) } }).commit());
  });

  test('nom déjà pris par un lobby actif refusé', async () => {
    await seedLobby('L1');
    await assertFails(createBatch('zoe', { pseudo: 'Zoé' }).commit());
  });

  test('reprendre le nom d’un lobby expiré autorisé', async () => {
    await seedLobby('L1', { expireAt: inHours(-1) });
    await assertSucceeds(createBatch('zoe', { pseudo: 'Zoé' }).commit());
  });

  test('reprendre le nom d’un lobby supprimé autorisé', async () => {
    await seed('lobbyNames/soir%C3%A9e', { lobbyId: 'disparu', expireAt: inHours(10) });
    await assertSucceeds(createBatch('zoe', { pseudo: 'Zoé' }).commit());
  });

  test('pointer un nom vers le lobby d’un autre refusé', async () => {
    await seedLobby('L1', { nameKey: 'autre' });
    await assertFails(
      setDoc(doc(db('eve'), 'lobbyNames/pirate'), { lobbyId: 'L1', expireAt: inHours(24) }),
    );
  });
});

describe('rejoindre', () => {
  test('bon mot de passe accepté', async () => {
    await seedLobby();
    await assertSucceeds(joinBatch('carol').commit());
    const data = await readLobbyRaw();
    if (data.members.carol !== 'Carol' || data.players.length !== 3) throw new Error('join non appliqué');
    // Il peut ensuite lire le lobby et supprimer sa preuve.
    await assertSucceeds(getDoc(doc(db('carol'), 'lobbies/L1')));
    await assertSucceeds(deleteDoc(doc(db('carol'), 'lobbies/L1/joins/carol')));
  });

  test('mauvais mot de passe refusé', async () => {
    await seedLobby();
    await assertFails(joinBatch('carol', { password: 'faux' }).commit());
  });

  test('sans preuve de mot de passe refusé', async () => {
    await seedLobby();
    await assertFails(
      updateDoc(doc(db('carol'), 'lobbies/L1'), {
        'members.carol': 'Carol',
        players: arrayUnion({ name: 'Carol', gender: 'F' }),
      }),
    );
  });

  test('pseudo déjà pris refusé', async () => {
    await seedLobby();
    await assertFails(
      joinBatch('carol', { pseudo: 'Bob', player: { name: 'Bob', gender: 'F' } }).commit(),
    );
  });

  test('ajouter un autre uid refusé', async () => {
    await seedLobby();
    const d = db('carol');
    const b = writeBatch(d);
    b.set(doc(d, 'lobbies/L1/joins/carol'), { password: 'secret' });
    b.update(doc(d, 'lobbies/L1'), {
      'members.dave': 'Dave',
      players: arrayUnion({ name: 'Dave', gender: 'H' }),
    });
    await assertFails(b.commit());
  });

  test('nom dans players différent de members[uid] refusé', async () => {
    await seedLobby();
    await assertFails(
      joinBatch('carol', { pseudo: 'Carol', player: { name: 'Bob', gender: 'H' } }).commit(),
    );
    await assertFails(
      joinBatch('carol', { pseudo: 'Carol', player: { name: 'Caroline', gender: 'F' } }).commit(),
    );
  });

  test('champ en trop ou genre invalide dans le joueur ajouté refusé', async () => {
    await seedLobby();
    await assertFails(
      joinBatch('carol', { player: { name: 'Carol', gender: 'F', score: 99 } }).commit(),
    );
    await assertFails(joinBatch('carol', { player: { name: 'Carol', gender: 'X' } }).commit());
  });

  test('modifier un ancien joueur en rejoignant refusé', async () => {
    await seedLobby();
    const d = db('carol');
    const b = writeBatch(d);
    b.set(doc(d, 'lobbies/L1/joins/carol'), { password: 'secret' });
    b.update(doc(d, 'lobbies/L1'), {
      'members.carol': 'Carol',
      players: [
        { name: 'Alice', gender: 'F' },
        { name: 'Bob', gender: 'F' }, // modifié
        { name: 'Carol', gender: 'F' },
      ],
    });
    await assertFails(b.commit());
  });

  test('retirer un joueur en rejoignant refusé', async () => {
    await seedLobby();
    const d = db('carol');
    const b = writeBatch(d);
    b.set(doc(d, 'lobbies/L1/joins/carol'), { password: 'secret' });
    b.update(doc(d, 'lobbies/L1'), {
      'members.carol': 'Carol',
      players: [
        { name: 'Alice', gender: 'F' },
        { name: 'Carol', gender: 'F' },
      ],
    });
    await assertFails(b.commit());
  });

  test('toucher à un autre champ en rejoignant refusé', async () => {
    await seedLobby();
    const d = db('carol');
    const b = writeBatch(d);
    b.set(doc(d, 'lobbies/L1/joins/carol'), { password: 'secret' });
    b.update(doc(d, 'lobbies/L1'), {
      'members.carol': 'Carol',
      players: arrayUnion({ name: 'Carol', gender: 'F' }),
      status: 'playing',
    });
    await assertFails(b.commit());
  });

  test('preuve de mot de passe illisible, même par son auteur', async () => {
    await seedLobby();
    await assertSucceeds(setDoc(doc(db('carol'), 'lobbies/L1/joins/carol'), { password: 'secret' }));
    await assertFails(getDoc(doc(db('carol'), 'lobbies/L1/joins/carol')));
    await assertFails(setDoc(doc(db('carol'), 'lobbies/L1/joins/dave'), { password: 'secret' }));
  });

  test('lobby ancien format (sans members) : impossible de rejoindre', async () => {
    const legacy = baseLobby();
    delete legacy.members;
    delete legacy.hostUid;
    await seed('lobbies/OLD', legacy);
    await assertFails(joinBatch('carol', { lobbyId: 'OLD' }).commit());
    await assertFails(getDoc(doc(db('carol'), 'lobbies/OLD')));
  });
});

describe('mises à jour par les membres', () => {
  test('un membre peut modifier l’état de jeu', async () => {
    await seedLobby();
    await assertSucceeds(
      updateDoc(doc(db('bob'), 'lobbies/L1'), {
        status: 'playing',
        currentQuestion: 'Q1',
        activePlayers: [{ name: 'Bob', gender: 'H' }],
      }),
    );
  });

  test('un non-membre ne peut rien modifier', async () => {
    await seedLobby();
    await assertFails(updateDoc(doc(db('eve'), 'lobbies/L1'), { status: 'playing' }));
  });

  test('champs figés : password, lobbyName, nameKey, createdAt, expireAt', async () => {
    await seedLobby();
    const ref = doc(db('alice'), 'lobbies/L1');
    await assertFails(updateDoc(ref, { password: 'autre' }));
    await assertFails(updateDoc(ref, { lobbyName: 'Autre' }));
    await assertFails(updateDoc(ref, { nameKey: 'autre' }));
    await assertFails(updateDoc(ref, { createdAt: Timestamp.now() }));
    await assertFails(updateDoc(ref, { expireAt: inHours(40) }));
  });

  test('un membre ne peut pas ajouter ni renommer un membre', async () => {
    await seedLobby();
    const ref = doc(db('bob'), 'lobbies/L1');
    await assertFails(updateDoc(ref, { 'members.dave': 'Dave' }));
    await assertFails(updateDoc(ref, { 'members.alice': 'Pirate' }));
    await assertFails(updateDoc(ref, { 'members.bob': 'Bobby' }));
  });

  test('un non-chef ne peut pas exclure', async () => {
    await seedLobby();
    await assertFails(updateDoc(doc(db('bob'), 'lobbies/L1'), { 'members.alice': deleteField() }));
  });

  test('le chef peut exclure un joueur', async () => {
    await seedLobby();
    await assertSucceeds(
      updateDoc(doc(db('alice'), 'lobbies/L1'), {
        'members.bob': deleteField(),
        players: [{ name: 'Alice', gender: 'F' }],
        activePlayers: [],
      }),
    );
    // L'exclu ne peut plus lire.
    await assertFails(getDoc(doc(db('bob'), 'lobbies/L1')));
  });

  test('le chef ne peut pas exclure deux joueurs d’un coup', async () => {
    await seedLobby('L1', {
      members: { alice: 'Alice', bob: 'Bob', carol: 'Carol' },
    });
    await assertFails(
      updateDoc(doc(db('alice'), 'lobbies/L1'), {
        'members.bob': deleteField(),
        'members.carol': deleteField(),
      }),
    );
  });

  test('un membre peut partir', async () => {
    await seedLobby();
    await assertSucceeds(
      updateDoc(doc(db('bob'), 'lobbies/L1'), {
        'members.bob': deleteField(),
        players: [{ name: 'Alice', gender: 'F' }],
      }),
    );
  });

  test('un non-chef ne peut pas prendre le rôle de chef', async () => {
    await seedLobby();
    await assertFails(updateDoc(doc(db('bob'), 'lobbies/L1'), { hostUid: 'bob', host: 'Bob' }));
    await assertFails(updateDoc(doc(db('bob'), 'lobbies/L1'), { host: 'Bob' }));
  });

  test('le chef part et transmet le rôle à un membre', async () => {
    await seedLobby();
    await assertSucceeds(
      updateDoc(doc(db('alice'), 'lobbies/L1'), {
        'members.alice': deleteField(),
        players: [{ name: 'Bob', gender: 'H' }],
        host: 'Bob',
        hostUid: 'bob',
      }),
    );
  });

  test('le chef ne peut pas transmettre le rôle à un non-membre ou avec un mauvais pseudo', async () => {
    await seedLobby();
    const ref = doc(db('alice'), 'lobbies/L1');
    await assertFails(updateDoc(ref, { host: 'Eve', hostUid: 'eve' }));
    await assertFails(updateDoc(ref, { host: 'Alice', hostUid: 'bob' }));
  });

  test('plus de 20 joueurs refusé', async () => {
    await seedLobby();
    const players = Array.from({ length: 21 }, (_, i) => ({ name: `J${i}`, gender: 'H' }));
    await assertFails(updateDoc(doc(db('alice'), 'lobbies/L1'), { players }));
  });
});

describe('suppression du lobby', () => {
  test('le dernier membre peut supprimer', async () => {
    await seedLobby('L1', { members: { alice: 'Alice' }, players: [{ name: 'Alice', gender: 'F' }] });
    await assertSucceeds(deleteDoc(doc(db('alice'), 'lobbies/L1')));
  });

  test('suppression refusée avec 2 membres', async () => {
    await seedLobby();
    await assertFails(deleteDoc(doc(db('alice'), 'lobbies/L1')));
  });

  test('suppression refusée avec 2 membres même si players a été vidé', async () => {
    await seedLobby();
    await assertSucceeds(updateDoc(doc(db('bob'), 'lobbies/L1'), { players: [] }));
    await assertFails(deleteDoc(doc(db('bob'), 'lobbies/L1')));
    await assertFails(deleteDoc(doc(db('alice'), 'lobbies/L1')));
  });

  test('un non-membre ne peut pas supprimer un lobby actif', async () => {
    await seedLobby('L1', { members: { alice: 'Alice' }, players: [{ name: 'Alice', gender: 'F' }] });
    await assertFails(deleteDoc(doc(db('eve'), 'lobbies/L1')));
  });

  test('le dernier membre supprime lobby + nom dans le même batch', async () => {
    await seedLobby('L1', { members: { alice: 'Alice' }, players: [{ name: 'Alice', gender: 'F' }] });
    const d = db('alice');
    const b = writeBatch(d);
    b.delete(doc(d, 'lobbies/L1'));
    b.delete(doc(d, 'lobbyNames/soir%C3%A9e'));
    await assertSucceeds(b.commit());
  });

  test('supprimer le nom d’un lobby actif refusé', async () => {
    await seedLobby();
    await assertFails(deleteDoc(doc(db('alice'), 'lobbyNames/soir%C3%A9e')));
  });
});

describe('chat', () => {
  const msg = (uid, sender, extra = {}) => ({
    text: 'Salut',
    sender,
    senderUid: uid,
    timestamp: serverTimestamp(),
    ...extra,
  });

  test('un membre peut lire et écrire', async () => {
    await seedLobby();
    await assertSucceeds(addDoc(collection(db('bob'), 'lobbies/L1/messages'), msg('bob', 'Bob')));
    await assertSucceeds(getDocs(collection(db('bob'), 'lobbies/L1/messages')));
  });

  test('usurpation de pseudo refusée', async () => {
    await seedLobby();
    await assertFails(addDoc(collection(db('bob'), 'lobbies/L1/messages'), msg('bob', 'Alice')));
  });

  test('usurpation d’uid refusée', async () => {
    await seedLobby();
    await assertFails(addDoc(collection(db('bob'), 'lobbies/L1/messages'), msg('alice', 'Alice')));
  });

  test('message trop long ou champ en trop refusé', async () => {
    await seedLobby();
    const col = collection(db('bob'), 'lobbies/L1/messages');
    await assertFails(addDoc(col, msg('bob', 'Bob', { text: 'x'.repeat(501) })));
    await assertFails(addDoc(col, msg('bob', 'Bob', { pinned: true })));
  });

  test('un non-membre ne peut ni lire ni écrire', async () => {
    await seedLobby();
    await assertFails(getDocs(collection(db('eve'), 'lobbies/L1/messages')));
    await assertFails(addDoc(collection(db('eve'), 'lobbies/L1/messages'), msg('eve', 'Eve')));
  });

  test('modifier un message refusé', async () => {
    await seedLobby();
    await seed('lobbies/L1/messages/m1', { text: 'a', sender: 'Bob', senderUid: 'bob', timestamp: Timestamp.now() });
    await assertFails(updateDoc(doc(db('bob'), 'lobbies/L1/messages/m1'), { text: 'b' }));
  });

  test('suppression par un membre refusée tant qu’il reste 2 membres, même si players est vide', async () => {
    await seedLobby('L1', { players: [] });
    await seed('lobbies/L1/messages/m1', { text: 'a', sender: 'Bob', senderUid: 'bob', timestamp: Timestamp.now() });
    await assertFails(deleteDoc(doc(db('bob'), 'lobbies/L1/messages/m1')));
  });

  test('suppression par le dernier membre autorisée', async () => {
    await seedLobby('L1', { members: { alice: 'Alice' }, players: [{ name: 'Alice', gender: 'F' }] });
    await seed('lobbies/L1/messages/m1', { text: 'a', sender: 'Bob', senderUid: 'bob', timestamp: Timestamp.now() });
    await assertSucceeds(deleteDoc(doc(db('alice'), 'lobbies/L1/messages/m1')));
  });
});

describe('nettoyage des lobbys expirés', () => {
  test('lister les lobbys expirés autorisé, actifs refusé', async () => {
    await seedLobby('OLD', { expireAt: inHours(-2), nameKey: 'vieux' });
    await seedLobby('NEW', { nameKey: 'neuf' });
    const d = db('eve');
    const res = await assertSucceeds(
      getDocs(query(collection(d, 'lobbies'), where('expireAt', '<', Timestamp.now()))),
    );
    if (res.size !== 1 || res.docs[0].id !== 'OLD') throw new Error(`attendu OLD seul, reçu ${res.size}`);
  });

  test('un inconnu nettoie un lobby expiré : messages, nom, lobby', async () => {
    await seedLobby('OLD', { expireAt: inHours(-2), nameKey: 'vieux' });
    await seed('lobbies/OLD/messages/m1', { text: 'a', sender: 'Bob', senderUid: 'bob', timestamp: Timestamp.now() });
    const d = db('eve');
    const msgs = await assertSucceeds(getDocs(collection(d, 'lobbies/OLD/messages')));
    const b = writeBatch(d);
    msgs.forEach((m) => b.delete(m.ref));
    b.delete(doc(d, 'lobbyNames/vieux'));
    b.delete(doc(d, 'lobbies/OLD'));
    await assertSucceeds(b.commit());
  });

  test('messages d’un lobby déjà supprimé : lecture et suppression autorisées', async () => {
    await seed('lobbies/GONE/messages/m1', { text: 'a', sender: 'Bob', senderUid: 'bob', timestamp: Timestamp.now() });
    await assertSucceeds(getDocs(collection(db('eve'), 'lobbies/GONE/messages')));
    await assertSucceeds(deleteDoc(doc(db('eve'), 'lobbies/GONE/messages/m1')));
  });
});
