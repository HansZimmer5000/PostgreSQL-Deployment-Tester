\setrandom id0 1 50875000
\set id1 :id0+1
\set id2 :id1+1
\set id3 :id2+1
BEGIN;
INSERT INTO testtable (id) VALUES (:id0);
INSERT INTO testtable (id) VALUES (:id1);
INSERT INTO testtable (id) VALUES (:id2);
INSERT INTO testtable (id) VALUES (:id3);

DELETE FROM testtable WHERE (testtable.id = :id0);
DELETE FROM testtable WHERE (testtable.id = :id1);
DELETE FROM testtable WHERE (testtable.id = :id2);
DELETE FROM testtable WHERE (testtable.id = :id3);

INSERT INTO testtable (id) VALUES (:id0);
INSERT INTO testtable (id) VALUES (:id1);
INSERT INTO testtable (id) VALUES (:id2);
INSERT INTO testtable (id) VALUES (:id3);
END;