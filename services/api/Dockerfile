FROM dart:stable AS build
WORKDIR /app
COPY packages/contracts packages/contracts
COPY services/api services/api
WORKDIR /app/services/api
RUN dart pub get && dart compile exe bin/server.dart -o /app/server
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/server /app/server
USER 65534:65534
EXPOSE 8080
ENTRYPOINT ["/app/server"]
