/*
Script pour la SAE Exploitation base de données R2.04 :
    - Contient la partie 1,2,3 sans distinctions dans le code.
    - Tout est commenté pour aider à la compréhension.
    - Le code à été Réalisé en collaboration avec Hayek Sofiene, Lannuzel Dylan, Caillaud Maxime.

Le script contient deux parties :
    - Une premiere partie permettent la creation de la base de données vierge.
    - Une seconde partie permettant de tester les differentes procédures et vues crées par le script.
 */


--# Suppression de toute la base de données #--

drop table if exists "user" cascade;

drop table if exists groupe cascade;

drop table if exists matiere cascade;

drop table if exists evaluation cascade;

drop table if exists etudiant cascade;

drop table if exists professeur cascade;

drop table if exists chefmatiere cascade;

drop table if exists note cascade;

drop table if exists user_log cascade;

drop table if exists note_log cascade;

drop table if exists eval_log cascade;

drop table if exists matiere_log cascade;

drop function if exists tg_user() cascade;

drop function if exists tg_eval() cascade;

drop function if exists tg_note() cascade;

drop function if exists tg_matiere() cascade;

drop function if exists mes_moyennes(out integer, out varchar, out numeric, out numeric) cascade;

drop function if exists ma_moyenne_generale() cascade;

drop function if exists notes_etudiants(out varchar, out varchar, out varchar, out numeric) cascade;

drop function if exists moyenne_etudiants(out varchar, out numeric) cascade;

drop function if exists moyenne(out varchar, out numeric) cascade;

drop function if exists ajouter_eval(varchar, numeric) cascade;

drop function if exists ajouter_note(integer, integer, numeric) cascade;


 --# Role permettant l'accès aux vues #--

drop role if exists view_access;

create role view_access;

--# Creation des tables #--

create table if not exists "user" (
    id_user serial primary key,
    levelaccess varchar(40)
);

create table if not exists groupe(
    id_group serial primary key ,
    nom varchar(40)
);

create table if not exists matiere(
    id_matiere serial primary key ,
    coef decimal(4,2),
    nom varchar(40)
);

create table if not exists evaluation(
    id_eval serial primary key ,
    id_matiere integer,
    coef decimal(4,2),
    nom varchar(40)
);

create table if not exists etudiant (
    id_user int primary key,
    name varchar(40),
    id_group integer
);

create table if not exists professeur (
    id_user int,
    name varchar(40),
    id_group integer,
    primary key (id_user,id_group)
);

create table if not exists chefmatiere (
    id_user int primary key,
    name varchar(40),
    id_matiere integer
);

create table if not exists note(
    id_user integer,
    id_eval integer,
    note decimal(4,2),
    primary key (id_user,id_eval)
);

create table if not exists user_log(
    action text,
    timestamp timestamp default current_timestamp,
    old_user "user",
    new_user "user",
    by name
);

create table if not exists note_log(
    action text,
    timestamp timestamp default current_timestamp,
    old_note note,
    new_note note,
    by name

);

create table if not exists eval_log(
    action text,
    timestamp timestamp default current_timestamp,
    old_eval evaluation,
    new_eval evaluation,
    by name

);

create table if not exists matiere_log(
    action text,
    timestamp timestamp default current_timestamp,
    old_matiere matiere,
    new_matiere matiere,
    by name
);

--# Creation des differents triggers #--

create or replace function tg_user() returns trigger as
    $$
    BEGIN
        /*
         La procédure repond à plusieurs besoin :
            - Elle crée un utilisateur pour chaque insertion dans la table "USER" ou supprime un utilisateur pour chaque retrait dans la table "USER".
            - Elle insert, dans la table correspondant au niveau d'acces, un nouvel etudiant, professeur ou chefmatiere.
            - Elle met à jour le journal d'activités "USER_LOG".
         */
        if tg_op='INSERT' then

            execute 'create user "' || new.id_user || '" with password ' || quote_literal('azerty123'); -- Mot de passe par défaut : 'azerty123'

            execute 'grant view_access to "' || new.id_user || '"';

            insert into user_log(action, new_user, by) VALUES (tg_op::text,new, session_user);

            if new.levelaccess='etudiant' then
                insert into etudiant(id_user) values (new.id_user);
            elsif new.levelaccess='professeur' then
                insert into professeur(id_user,id_group) values (new.id_user,-1);
            elsif new.levelaccess='chefmatiere' then
                insert into chefmatiere(id_user) values (new.id_user);
            end if;

        elsif tg_op='UPDATE' then

            insert into user_log(action, old_user, new_user, by) VALUES (tg_op::text,old,new, session_user);

            if old.levelaccess='professeur' and new.levelaccess='chefmatiere' then
                delete from professeur where professeur.id_user=old.id_user;
                insert into chefmatiere(id_user) values (new.id_user);
            elsif old.levelaccess='chefmatiere' and new.levelaccess='professeur' then
                delete from professeur where professeur.id_user=old.id_user;
                insert into professeur(id_user,id_group) values (new.id_user,-1);
            end if;

        else

            execute 'drop user "' || old.id_user || '"';

            insert into user_log(action,old_user, by) values (tg_op::text,old, session_user);

            if old.levelaccess='etudiant' then
                delete from etudiant where etudiant.id_user=old.id_user;
                delete from "user" where id_user=old.id_user;
            elsif old.levelaccess='professeur' then
                delete from professeur where professeur.id_user=old.id_user;
            elsif old.levelaccess='chefmatiere' then
                delete from chefmatiere where chefmatiere.id_user=old.id_user;
            end if;

        end if;
    return null;
    end
    $$ language plpgsql;

create trigger tg_user
    after insert or delete or update on "user"
    for each row
    execute procedure tg_user();

create or replace function tg_eval() returns trigger as
    $$
    -- Mise a jour du journal d'activités "EVAL_LOG"
    BEGIN

        insert into eval_log(action, old_eval, new_eval, by) VALUES (tg_op::text, old, new, session_user);
    return null;
    end
    $$ language plpgsql;

create trigger tg_eval
    after insert or delete or update on evaluation
    for each row
    execute procedure tg_eval();

create or replace function tg_note() returns trigger as
    $$
    -- Mise a jour du journal d'activités "NOTE_LOG"
    BEGIN
        insert into note_log(action, old_note, new_note, by) VALUES (tg_op::text, old, new, session_user);
    return null;
    end
    $$ language plpgsql;

create trigger tg_note
    after insert or delete or update on note
    for each row
    execute procedure tg_note();

create or replace function tg_matiere() returns trigger as
    $$
    -- Mise a jour du journal d'activités "MATIERE_LOG"
    BEGIN
        insert into matiere_log(action, old_matiere, new_matiere, by) VALUES (tg_op::text, old, new, session_user);
    return null;
    end
    $$ language plpgsql;

create trigger tg_matiere
    after insert or delete or update on matiere
    for each row
    execute procedure tg_matiere();


--# Creation des vues et des procédures #--


-- Affiche toutes les notes de l'élève connecté
create or replace view MesNotes as
    select
        evaluation.nom,
        matiere.nom as nom_matiere,
        note.note
    from note, evaluation, matiere
    where
        cast(session_user as varchar)=cast(note.id_user as varchar) and
        evaluation.id_eval=note.id_eval and
        matiere.id_matiere=evaluation.id_matiere
    order by matiere.nom;

GRANT SELECT ON public.mesnotes TO view_access;

-- Affiche les moyennes de l'élève connecté selon les matières
create or replace function Mes_moyennes(out matiere varchar, out moyenne decimal(4, 2), out coeff decimal(4, 2)) returns setof record as
    $$
    DECLARE
        i record;
        r record;
        count decimal(4, 2);
    BEGIN
        for r in (select distinct m.id_matiere, m.nom, m.coef from note inner join evaluation on note.id_eval = evaluation.id_eval inner join matiere m on evaluation.id_matiere=m.id_matiere where cast(note.id_user as varchar)=cast(session_user as varchar) order by m.id_matiere) loop
            matiere=r.nom;
            coeff = r.coef;
            moyenne=0;
            count=0;
            for i in (select note.note, evaluation.coef from note inner join evaluation on note.id_eval = evaluation.id_eval inner join matiere m on evaluation.id_matiere=m.id_matiere where cast(note.id_user as varchar)=cast(session_user as varchar) and m.nom=r.nom group by note.note, evaluation.coef) loop
                moyenne=moyenne + (i.note * i.coef);
                count=count + i.coef;
            end loop;
            if count=0 then
                moyenne=null;
            else
                moyenne=round(moyenne/count,2);
            end if;
            return next;
        end loop;
    end
    $$ language plpgsql
    security definer;


--Affiche la moyenne generale de l'élève connecté
create or replace function Ma_moyenne_generale() returns decimal(4,2)
as
    $$
    DECLARE
        mean decimal;
        count decimal;
        r record;
    BEGIN
        mean=0;
        count=0;
        for r in (select moyenne, coeff from Mes_moyennes()) loop
            mean=mean+(r.moyenne*r.coeff);
            count=count+r.coeff;
        end loop;
        if count=0 then
            return null;
        else
            return round(mean/count, 2);
        end if;
    END
    $$ language plpgsql
    security definer;

/*
 Plusieurs possibilités :
    - Si professeur connecté : Affiche les notes de tout les élèves du groupe correspondant au professeur
    - Si chefmatiere connecté : Affiche les notes de tout les élèves ayant déjà effectué un controle dans la matière correspondant au chef
 */
create or replace function Notes_etudiants(out NomEleve varchar,out Matieres varchar,out Evaluations varchar, out Notes decimal) returns setof record as
    $$
    DECLARE
        level varchar;
        curs refcursor;
    BEGIN
        select levelaccess from "user" where cast(id_user as varchar)=cast(session_user as varchar) into level;
        if level='professeur' then
            -- AFFICHER LES NOTES DES ELEVES APPARTENANT AU GROUPE DU PROF
            open curs for
                select etudiant.name,matiere.nom,evaluation.nom ,note from etudiant join note on note.id_user=etudiant.id_user join professeur on etudiant.id_group=professeur.id_group join evaluation on note.id_eval = evaluation.id_eval join matiere on evaluation.id_matiere = matiere.id_matiere where cast(professeur.id_user as varchar)=cast(session_user as varchar) and etudiant.id_group = professeur.id_group  order by etudiant.id_user;
            loop
                fetch curs into NomEleve,Matieres,Evaluations,Notes ;
                exit when not FOUND;
                return next;
            end loop;
            close curs;
        end if;
        if level='chefmatiere' then
            -- AFFICHER LES NOTES DES ELEVES AYANT DES NOTES DANS LA MATIERE DU CHEFMATIERE
            open curs for
                select etudiant.name,matiere.nom,evaluation.nom,note from etudiant join note on note.id_user = etudiant.id_user natural join evaluation join matiere on evaluation.id_matiere = matiere.id_matiere join chefmatiere on matiere.id_matiere = chefmatiere.id_matiere where cast(chefmatiere.id_user as varchar)=cast(session_user as varchar) and chefmatiere.id_matiere = evaluation.id_matiere order by etudiant.id_user;
            loop
                fetch curs into NomEleve,Matieres,Evaluations,Notes;
                exit when not FOUND;
                return next;
            end loop;
            close curs;
        end if;
    end;
    $$ language plpgsql
    security definer;


/*
 Plusieurs possibilités :
    - Si professeur connecté : Affiche la moyenne de tout les élèves du groupe correspondant au professeur
    - Si chefmatiere connecté : Affiche la moyenne de tout les élèves ayant déjà effectué un controle dans la matière correspondant au chef
 */
create or replace function Moyenne_etudiants(out NomEleve varchar,out Moyenne decimal) returns setof record as
    $$
    DECLARE
        level varchar;
        curs refcursor;
    BEGIN
        select levelaccess from "user" where cast(id_user as varchar)=cast(session_user as varchar) into level;
        if level='professeur' then
            -- AFFICHER LES NOTES DES ELEVES APPARTENANT AU GROUPE DU PROF
            open curs for
                select etudiant.name,avg(note.note) from etudiant join note on note.id_user=etudiant.id_user join professeur on etudiant.id_group=professeur.id_group join evaluation on note.id_eval = evaluation.id_eval join matiere on evaluation.id_matiere = matiere.id_matiere where cast(professeur.id_user as varchar)=cast(session_user as varchar) and etudiant.id_group = professeur.id_group group by etudiant.name;
            loop
                fetch curs into NomEleve,Moyenne ;
                exit when not FOUND;
                return next;
            end loop;
            close curs;
        end if;
        if level='chefmatiere' then
            -- AFFICHER LES NOTES DES ELEVES AYANT DES NOTES DANS LA MATIERE DU CHEFMATIERE
            open curs for
                select etudiant.name,avg(note.note) from etudiant join note on note.id_user = etudiant.id_user natural join evaluation join matiere on evaluation.id_matiere = matiere.id_matiere join chefmatiere on matiere.id_matiere = chefmatiere.id_matiere where cast(chefmatiere.id_user as varchar)=cast(session_user as varchar) and chefmatiere.id_matiere = evaluation.id_matiere group by etudiant.name;
            loop
                fetch curs into NomEleve,Moyenne;
                exit when not FOUND;
                return next;
            end loop;
            close curs;
        end if;
    end;
    $$ language plpgsql
    security definer;


/*
 Plusieurs possibilités :
    - Si professeur connecté : Affiche la moyenne du groupe correspondant au professeur
    - Si chefmatiere connecté : Affiche la moyenne de la matière correspondant au chef
 */
create or replace function Moyenne(out LeGroupe varchar,out Moyenne decimal) returns setof record as
    $$
    DECLARE
        level varchar;
        curs refcursor;
    BEGIN
        select levelaccess from "user" where cast(id_user as varchar)=cast(session_user as varchar) into level;
        if level='professeur' then
            -- AFFICHER LES NOTES DES ELEVES APPARTENANT AU GROUPE DU PROF
            open curs for
                select groupe.nom,avg(note.note) from etudiant join note on note.id_user=etudiant.id_user join professeur on etudiant.id_group=professeur.id_group join groupe on groupe.id_group=professeur.id_group join evaluation on note.id_eval = evaluation.id_eval join matiere on evaluation.id_matiere = matiere.id_matiere where cast(professeur.id_user as varchar)=cast(session_user as varchar) and etudiant.id_group = professeur.id_group group by groupe.nom;
            loop
                fetch curs into LeGroupe,Moyenne ;
                exit when not FOUND;
                return next;
            end loop;
            close curs;
        end if;
        if level='chefmatiere' then
            -- AFFICHER LES NOTES DES ELEVES AYANT DES NOTES DANS LA MATIERE DU CHEFMATIERE
            open curs for
                select matiere.nom,avg(note.note) from etudiant join note on note.id_user = etudiant.id_user natural join evaluation join matiere on evaluation.id_matiere = matiere.id_matiere join chefmatiere on matiere.id_matiere = chefmatiere.id_matiere where cast(chefmatiere.id_user as varchar)=cast(session_user as varchar) and chefmatiere.id_matiere = evaluation.id_matiere group by matiere.id_matiere;
            loop
                fetch curs into LeGroupe,Moyenne;
                exit when not FOUND;
                return next;
            end loop;
            close curs;
        end if;
    end;
    $$ language plpgsql
    security definer;


-- Procédure permettant aux chefmatieres de rajouter une évaluation dans la base de données
create or replace function ajouter_eval(in nom_eval varchar, in coeff decimal) returns void as
    $$
    DECLARE
        level varchar;
        m int;
    BEGIN
        -- UNIQUEMENT AUTORISER POUR UN CHEF MATIERE QUI A LA MATIERE CORRESPONDANTE
        select levelaccess from "user" where cast(id_user as varchar)=cast(session_user as varchar) into level;
        if level='chefmatiere' then
            select mat.id_matiere from matiere mat inner join chefmatiere c on mat.id_matiere = c.id_matiere where cast(c.id_user as varchar)=cast(session_user as varchar) into m;
            insert into evaluation(id_matiere, coef, nom) values (m, coeff, nom_eval);
        else
            raise exception 'Vous n''avez pas les droits pour ajouter une evaluation';
        end if;
    end
    $$ language plpgsql
    security definer;

-- Procédure permettant aux professeurs de rajouter une note dans la base de données
create or replace function ajouter_note(in iduser int, in ideval int, in lanote decimal) returns void as
    $$
    BEGIN
        -- UNIQUEMENT AUTORISER POUR UN PROFESSEUR CORRESPONDANT A SON ETUDIANT OU A UN CHEFMATIERE PEUT IMPORTE L'ETUDIANT
        if (select levelaccess from "user" where cast("user".id_user as varchar)=cast(session_user as varchar))='professeur' then
            insert into note(id_user, id_eval, note) values (iduser, ideval, lanote);
        else
            raise exception 'Vous n''avez pas les droits pour ajouter une note';
        end if;
    end
    $$ language plpgsql
    security definer;

-- POUR TESTER --

-- Uniquement après avoir utilisé le script connecté en tant que propriétaire de la base de données --


--# Création de données basiques #--

drop user if exists "1";
drop user if exists "2";
drop user if exists "3";
drop user if exists "4";
drop user if exists "5";

alter sequence if exists user_id_user_seq restart;

insert into "user" values(default,'etudiant');
insert into "user" values(default,'etudiant');
insert into "user" values(default,'etudiant');
insert into "user" values(default,'professeur');
insert into "user" values(default,'chefmatiere');

insert into groupe values(default,'Andromeda');

insert into matiere values(default,15,'JAVA');
insert into matiere values(default,4,'IHM');
insert into matiere values(default,10,'SQL');

insert into evaluation values(default,1,4,'Controle long');
insert into evaluation values(default,1,2,'Controle court');
insert into evaluation values(default,2,4,'Controle long');
insert into evaluation values(default,2,2,'Controle court');
insert into evaluation values(default,3,4,'Controle long');
insert into evaluation values(default,3,2,'Controle court');

insert into note values(1,1,14.5);
insert into note values(1,2,12.8);
insert into note values(1,3,10.2);
insert into note values(1,4,9.8);
insert into note values(1,5,17.4);
insert into note values(1,6,14.25);

insert into note values(2,1,17.8);
insert into note values(2,2,18.2);
insert into note values(2,3,14.2);
insert into note values(2,4,12.5);
insert into note values(2,5,16.5);
insert into note values(2,6,17.45);

insert into note values(3,1,9.5);
insert into note values(3,2,4.5);
insert into note values(3,3,7.88);
insert into note values(3,4,2.11);
insert into note values(3,5,9);
insert into note values(3,6,18.4);

update etudiant set name = 'Maxime' where id_user=1;
update etudiant set name = 'Sofiene' where id_user=2;
update etudiant set name = 'Dylan' where id_user=3;
update etudiant set id_group = 1;
update etudiant set id_group = 2 where id_user=3;
update professeur set id_group = 1;
update chefmatiere set id_matiere = 1;

--# Connecté en tant qu'étudiant ( Utilisateur 1,2 ou 3 ; Mdp par défaut : 'azerty123' ) #--

select * from mesnotes;
select * from mes_moyennes();
select * from ma_moyenne_generale();
select * from notes_etudiants(); -- Le resultat est vide car l'étudiant ne peux pas avoir accès aux notes des autres étudiants

--# Connecté en tant que chefmatiere ( Utilisateur 5 ; Mdp par défaut : 'azerty123' ) #--

select * from notes_etudiants();
select * from Moyenne_etudiants();
select * from Moyenne();
select ajouter_eval('Controle surprise',1);

--# Connecté en tant que professeur ( Utilisateur 4 ; Mdp par défaut : 'azerty123' ) #--

select ajouter_note(1,7,9.8);
select * from notes_etudiants();
select * from Moyenne_etudiants();
select * from Moyenne();
select ajouter_eval('Controle non déclaré',40); -- Ici, l'erreur est normal, le professeur n'a pas le droit de rajouter une evaluation.




