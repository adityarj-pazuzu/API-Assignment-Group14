"""Retrieve Prefect flow, deployment, and run details for assignment evidence."""

from prefect import get_client
import asyncio


def safe(obj: object, attr: str, default: object = "NA"):
    """Safely fetch an attribute from an object."""
    return getattr(obj, attr, default)


def schedule_summary(deployment):
    """Return a readable schedule summary for a deployment."""
    schedule = safe(deployment, "schedule", None)
    if not schedule:
        return "None"

    interval = safe(schedule, "interval", None)
    cron = safe(schedule, "cron", None)
    timezone = safe(schedule, "timezone", "NA")

    if interval:
        return f"interval={interval}, timezone={timezone}"
    if cron:
        return f"cron={cron}, timezone={timezone}"
    return str(schedule)


async def get_application_details():
    """Print flow, deployment, and recent run metadata from the configured Prefect API."""
    async with get_client() as client:
        flows = await client.read_flows()
        print(f"Flow count: {len(flows)}")
        print("Flows:")
        if not flows:
            print("  (none)")
        for flow in flows[:5]:
            print(f"  - Flow ID: {safe(flow, 'id')}")
            print(f"    Name: {safe(flow, 'name')}")
            print(f"    Created: {safe(flow, 'created')}")
            print(f"    Updated: {safe(flow, 'updated')}")

        deployments = await client.read_deployments()
        print(f"\nDeployment count: {len(deployments)}")
        print("Deployments:")
        if not deployments:
            print("  (none)")
        for deployment in deployments[:5]:
            print(f"  - Deployment ID: {safe(deployment, 'id')}")
            print(f"    Name: {safe(deployment, 'name')}")
            print(f"    Flow ID: {safe(deployment, 'flow_id')}")
            print(f"    Paused: {safe(deployment, 'paused')}")
            print(f"    Schedule: {schedule_summary(deployment)}")
            print(f"    Created: {safe(deployment, 'created')}")
            print(f"    Updated: {safe(deployment, 'updated')}")

        runs = await client.read_flow_runs(limit=10)
        print(f"\nRecent flow runs (last {len(runs)}):")
        if not runs:
            print("  (none)")
        for run in runs:
            state = safe(run, "state", None)
            state_name = safe(state, "name", "UNKNOWN")
            print(f"  - Run ID: {safe(run, 'id')}")
            print(f"    Name: {safe(run, 'name')}")
            print(f"    State: {state_name}")
            print(f"    Start: {safe(run, 'start_time')}")
            print(f"    End: {safe(run, 'end_time')}")
            print(f"    Deployment ID: {safe(run, 'deployment_id')}")

        if flows:
            try:
                print("\nFlow fields:", list(flows[0].model_dump().keys()))
            except Exception:
                pass
        if deployments:
            try:
                print("Deployment fields:", list(deployments[0].model_dump().keys()))
            except Exception:
                pass


if __name__ == "__main__":
    asyncio.run(get_application_details())
