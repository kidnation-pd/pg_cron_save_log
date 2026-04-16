CREATE TABLE users (
	id SERIAL PRIMARY KEY,
	name TEXT,
	email TEXT,
	role TEXT,
	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE users_audit (
	id SERIAL PRIMARY KEY,
	user_id INTEGER,
	changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	changed_by TEXT,
	field_changed TEXT,
	old_value TEXT,
	new_value TEXT
);

-- Триггерная функция логирования изменений
create or replace function log_users_audit()
-- Возвращает триггер
returns trigger as $$
begin
	-- Проверка изменения имени
	if (old.name is distinct from new.name) then
		insert into users_audit(user_id, changed_by, field_changed, old_value, new_value)
		values (new.id, current_user, 'name', old.name, new.name);
	end if;

	-- Проверка изменения email
	if (old.email is distinct from new.email) then
		insert into users_audit(user_id, changed_by, field_changed, old_value, new_value)
		values (new.id, current_user, 'email', old.email, new.email);
	end if;

	-- Проверка изменения роли
	if (old.role is distinct from new.role) then
		insert into users_audit(user_id, changed_by, field_changed, old_value, new_value)
		values (new.id, current_user, 'role', old.role, new.role);
	end if;

	return new;
end;
$$ language plpgsql;

-- Создание триггера для таблицы users
create trigger trigger_log_users_audit
-- Выполнять ПОСЛЕ обновлениея таблицы users
after update on users
-- Для каждой строки
for each row
-- Выполнение функции
execute function log_users_audit();

-- Тестовые данные
insert into users(name, email, role) values 
 ('Alice', 'alice@mbox.com', 'admin'),
 ('Bob', 'bob@mbox.com', 'moderator'),
 ('John', 'john@mbox.com', 'user');

-- Изменение
update users
set email = 'new.alice@mbox.com', role = 'user' where id = 1;

-- Изменение
update users
set email = 'john@mbox.com', role = 'moderator' where id = 3;

select * from users;
select * from users_audit;

-- Активация cron
create extension if not exists pg_cron;

-- Функция записи лога в CSV
create or replace function save_log_users_audit()
returns text as $$
declare
	-- Объявление переменной для формирования пути
	file_path text;
begin
	-- Присваиванине переменной сформированного пути
	file_path := '/tmp/users_audit_export_' || to_char(current_timestamp, 'YYYYMMDD_HH24MI') || '.csv';

    -- Выполнение SQL для сохранения лога в CSV
    execute format('copy (select * from users_audit where date(changed_at) = current_date - interval ''1 day'') to %L with (format csv, header true, delimiter '','')', file_path);
    
    return file_path;
end;
$$ language plpgsql;

-- Создание новой задачи
select cron.schedule (
	-- Имя задачи
	'save_log_users_audit',
	-- Расписание (3:00 UTC). В задании не сказано сказано прочасовой пояс (или это душно :-) )
	'0 0 * * *',
	-- Вызов функции
	'select save_log_users_audit()'
);
