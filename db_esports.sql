--criação de tabelas

create table modalidades (
    id serial primary key,
    nome varchar(100) not null unique,
    genero varchar(50) not null,
    quantidade_jogadores int not null
        check (quantidade_jogadores > 0)
);


create table torneios (
    id serial primary key,
    nome varchar(100) not null,
    modalidade_id int not null,
    data_inicio date not null,
    data_fim date not null,
    status varchar(30) not null default 'Planejado',

    foreign key (modalidade_id)
        references modalidades(id),

    check (data_fim >= data_inicio),

    check (status in (
        'Planejado',
        'Em Andamento',
        'Finalizado',
        'Cancelado'
    ))
);


create table jogadores (
    id serial primary key,
    nome varchar(100) not null,
    nickname varchar(50) not null unique,
    email varchar(100) not null unique,
    senha varchar(100) not null,
    data_cadastro timestamp default current_timestamp,
    status varchar(20) not null default 'Ativo',

    check (status in (
        'Ativo',
        'Inativo',
        'Banido'
    ))
);


create table inscricoes (
    id serial primary key,
    torneio_id int not null,
    jogador_id int not null,
    data_inscricao timestamp default current_timestamp,
    status varchar(20) not null default 'Ativa',

    foreign key (torneio_id)
        references torneios(id),

    foreign key (jogador_id)
        references jogadores(id),

    unique (torneio_id, jogador_id),

    check (status in (
        'Ativa',
        'Cancelada',
        'Desclassificada'
    ))
);


create table partidas (
    id serial primary key,
    torneio_id int not null,
    inscricao_id1 int not null,
    inscricao_id2 int not null,
    data_hora timestamp not null,
    data_criacao timestamp default current_timestamp,
    fase varchar(50) not null,
    status varchar(30) not null default 'Agendada',

    foreign key (torneio_id)
        references torneios(id),

    foreign key (inscricao_id1)
        references inscricoes(id),

    foreign key (inscricao_id2)
        references inscricoes(id),

    check (inscricao_id1 <> inscricao_id2),

    check (status in (
        'Agendada',
        'Em Andamento',
        'Finalizada',
        'Cancelada'
    ))
);


create table historico_partidas (
    id serial primary key,
    partida_id int not null,
    placar_jogador1 int default 0,
    placar_jogador2 int default 0,
    vencedor_id int,
    data_realizada timestamp,
    data_registro timestamp default current_timestamp,
    evento varchar(100) not null,

    foreign key (partida_id)
        references partidas(id),

    foreign key (vencedor_id)
        references jogadores(id),

    check (placar_jogador1 >= 0),
    check (placar_jogador2 >= 0)
);


--inserção de dados

insert into modalidades
(nome, genero, quantidade_jogadores)
values
('Counter-Strike 2', 'FPS', 10),
('League of Legends', 'MOBA', 10),
('FIFA', 'Esporte', 2);


insert into torneios
(nome, modalidade_id, data_inicio, data_fim, status)
values
('Campeonato CS2', 1, current_date, current_date + 30, 'Em Andamento'),
('Campeonato LoL', 2, current_date, current_date + 30, 'Em Andamento'),
('Campeonato FIFA', 3, current_date, current_date + 30, 'Em Andamento');


insert into jogadores
(nome, nickname, email, senha, status)
values
('Carlos Silva', 'Shadow', 'shadow@email.com', '123456', 'Ativo'),
('Joao Santos', 'Dragon', 'dragon@email.com', '123456', 'Ativo'),
('Pedro Oliveira', 'Phoenix', 'phoenix@email.com', '123456', 'Ativo'),
('Lucas Costa', 'Sniper', 'sniper@email.com', '123456', 'Ativo'),
('Marcos Souza', 'Darkness', 'darkness@email.com', '123456', 'Ativo'),
('Rafael Lima', 'Warrior', 'warrior@email.com', '123456', 'Ativo');


insert into inscricoes
(torneio_id, jogador_id, status)
values
(1, 1, 'Ativa'),
(1, 2, 'Ativa'),
(2, 3, 'Ativa'),
(2, 4, 'Ativa'),
(3, 5, 'Ativa'),
(3, 6, 'Ativa');


--fn_validar_partida

create or replace function fn_validar_partida()
returns trigger
language plpgsql
as $$
declare
    v_validos int;
begin

    select count(*)
    into v_validos
    from inscricoes i
    inner join jogadores j
        on i.jogador_id = j.id
    where i.id in (
        new.inscricao_id1,
        new.inscricao_id2
    )
    and i.torneio_id = new.torneio_id
    and i.status = 'Ativa'
    and j.status = 'Ativo';

    if v_validos <> 2 then
        raise exception
        'Partida nao permitida: os dois jogadores devem possuir inscricoes ativas e pertencer ao torneio.';
    end if;

    new.data_criacao := current_timestamp;

    return new;

end;
$$;


create trigger trg_validar_partida
before insert on partidas
for each row
execute function fn_validar_partida();


--fn_registrar_historico

create or replace function fn_registrar_historico()
returns trigger
language plpgsql
as $$
begin

    insert into historico_partidas (
        partida_id,
        placar_jogador1,
        placar_jogador2,
        data_registro,
        evento
    )
    values (
        new.id,
        0,
        0,
        current_timestamp,
        'Partida cadastrada'
    );

    return new;

end;
$$;


create trigger trg_registrar_historico_partida
after insert on partidas
for each row
execute function fn_registrar_historico();

--inserção das partidas
insert into partidas
(torneio_id, inscricao_id1, inscricao_id2, data_hora, fase, status)
values
(1, 1, 2, current_timestamp + interval '1 day', 'Final', 'Agendada'),
(2, 3, 4, current_timestamp + interval '2 days', 'Semifinal', 'Agendada'),
(3, 5, 6, current_timestamp + interval '3 days', 'Final', 'Agendada');


--fn_buscar_jogadores

create or replace function fn_buscar_jogadores(p_termo varchar)
returns table (
    id int,
    nome varchar,
    nickname varchar,
    email varchar,
    data_cadastro timestamp,
    status varchar
)
language plpgsql
as $$
begin

    return query

    select
        j.id,
        j.nome,
        j.nickname,
        j.email,
        j.data_cadastro,
        j.status
    from jogadores j
    where
        j.nickname ilike '%' || p_termo || '%'
        or j.email ilike '%' || p_termo || '%';

end;
$$;


--vw_painel_principal

create or replace view vw_painel_principal as

select
    j1.nickname as nickname_jogador,
    j1.nickname || ' x ' || j2.nickname as titulo_partida,
    m.nome as modalidade,
    p.data_hora as data_partida,
    p.status as status_disputa

from partidas p

inner join torneios t
    on p.torneio_id = t.id

inner join modalidades m
    on t.modalidade_id = m.id

inner join inscricoes i1
    on p.inscricao_id1 = i1.id

inner join jogadores j1
    on i1.jogador_id = j1.id

inner join inscricoes i2
    on p.inscricao_id2 = i2.id

inner join jogadores j2
    on i2.jogador_id = j2.id

union all

select
    j2.nickname as nickname_jogador,
    j1.nickname || ' x ' || j2.nickname as titulo_partida,
    m.nome as modalidade,
    p.data_hora as data_partida,
    p.status as status_disputa

from partidas p

inner join torneios t
    on p.torneio_id = t.id

inner join modalidades m
    on t.modalidade_id = m.id

inner join inscricoes i1
    on p.inscricao_id1 = i1.id

inner join jogadores j1
    on i1.jogador_id = j1.id

inner join inscricoes i2
    on p.inscricao_id2 = i2.id

inner join jogadores j2
    on i2.jogador_id = j2.id;


--vw_cronograma_partidas

create or replace view vw_cronograma_partidas as

select
    p.id as partida_id,
    t.nome as torneio,
    m.nome as modalidade,
    p.data_hora as data_agendada,
    p.status as status_partida,
    (p.data_hora::date - current_date) as dias_restantes,
    j.nickname as jogador_responsavel

from partidas p

inner join torneios t
    on p.torneio_id = t.id

inner join modalidades m
    on t.modalidade_id = m.id

inner join inscricoes i
    on p.inscricao_id1 = i.id

inner join jogadores j
    on i.jogador_id = j.id

order by
    p.data_hora asc,
    p.id asc;


--selects
select * from fn_buscar_jogadores('Shadow');

select * from vw_painel_principal;

select * from vw_cronograma_partidas

select
    id,
    partida_id,
    placar_jogador1,
    placar_jogador2,
    data_registro,
    evento
from historico_partidas;
