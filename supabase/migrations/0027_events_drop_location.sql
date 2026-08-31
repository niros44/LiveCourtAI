-- CourtSide — drop events.location, superseded by facility_id (UserStory 22).

alter table events drop column location;
