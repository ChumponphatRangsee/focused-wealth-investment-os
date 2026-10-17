
-- Guard against Edge workers appending JSONB string receipts via jsonb ||.
-- Preserve the current-state object contract on every future write.
create or replace function fwios.normalize_architecture_system_state_write_v1()
returns trigger language plpgsql as $$
declare normalized jsonb;
begin
 if new.state_key <> 'architecture_consolidation_v1' then return new; end if;
 if jsonb_typeof(new.state_value) = 'array' then
  select coalesce(jsonb_object_agg(k,v order by ord), '{}'::jsonb)
   into normalized
  from (
   select e.ord, case when jsonb_typeof(e.item)='string'
    then (e.item #>> '{}')::jsonb else e.item end as obj
   from jsonb_array_elements(new.state_value) with ordinality e(item,ord)
  ) x
  cross join lateral jsonb_each(x.obj) as fields(k,v);
  new.state_value := normalized;
 elsif jsonb_typeof(new.state_value)='string' then
  new.state_value := (new.state_value #>> '{}')::jsonb;
 end if;
 if jsonb_typeof(new.state_value) <> 'object' then
  raise exception 'architecture_consolidation_v1 requires JSON object';
 end if;
 return new;
end $$;
drop trigger if exists normalize_architecture_state_write_v1 on fwios.system_state;
create trigger normalize_architecture_state_write_v1
before insert or update of state_value on fwios.system_state
for each row execute function fwios.normalize_architecture_system_state_write_v1();
-- Repair the current value using the same mechanism; previous array retains all fields.
update fwios.system_state set state_value=state_value, updated_at=now()
where state_key='architecture_consolidation_v1';
