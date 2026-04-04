"""Retrieve Prefect flow and deployment details for assignment evidence."""

from prefect import get_client
import asyncio

async def get_application_details():
    """Print flow and deployment metadata from the configured Prefect API."""
    async with get_client() as client:
        # Retrieve flow metadata.
        flows = await client.read_flows()
        print(f"Flow count: {len(flows)}")
        print("Flows:")
        for flow in flows[:2]:
            print(f"Flow ID: {flow.id}, Name: {flow.name}")

        # Retrieve deployment metadata.
        deployments = await client.read_deployments()
        print(f"\nDeployment count: {len(deployments)}")
        print("\nDeployments:")
        for deployment in deployments[:2]:
            print(f"Deployment ID: {deployment.id}, Name: {deployment.name}")

if __name__ == "__main__":
    asyncio.run(get_application_details())
